class ProjektImports::CreateProjektFromImportService < ApplicationService
  LONG_TAIL_BUILDERS = {
    "poll_questions" => ProjektImports::Builders::PollBuilder,
    "events" => ProjektImports::Builders::EventBuilder,
    "milestones" => ProjektImports::Builders::MilestoneBuilder,
    "arguments" => ProjektImports::Builders::ArgumentBuilder,
    "notifications" => ProjektImports::Builders::NotificationBuilder,
    "progress_bars" => ProjektImports::Builders::ProgressBarBuilder,
    "livestreams" => ProjektImports::Builders::LivestreamBuilder,
    "point_of_interest_categories" => ProjektImports::Builders::PoiCategoryBuilder,
    "iframe" => ProjektImports::Builders::IframeBuilder,
    "budget" => ProjektImports::Builders::BudgetBuilder
  }.freeze

  ALLOWED_PROJEKT_SETTINGS = %w[
    projekt_feature.general.allow_downvoting_comments
    projekt_feature.general.consider_underway
    projekt_custom_feature.default_footer_tab
  ].freeze

  HIDDEN_DRAFT_SETTINGS = %w[
    projekt_feature.general.show_in_navigation
    projekt_feature.general.show_in_overview_page
    projekt_feature.general.show_in_homepage
    projekt_feature.general.allow_indexing
  ].freeze

  attr_reader :projekt_import

  def initialize(projekt_import:)
    @projekt_import = projekt_import
  end

  def call
    data = projekt_import.ai_result || {}
    if data["title"].blank?
      return ServiceResult.failure(error: I18n.t("adm.projekts.imports.errors.missing_title"))
    end

    projekt = nil

    ActiveRecord::Base.transaction do
      projekt = create_projekt(data)
      apply_subtitle(projekt, data["subtitle"])
      apply_tags_and_sdgs(projekt, data)

      phases = create_phases(projekt, data["phases"])
      create_content_blocks(projekt, data["content_blocks"])

      apply_projekt_settings(projekt, data["projekt_settings"])
      apply_phase_settings(phases, data["projekt_phase_settings"])
      enforce_hidden_draft_state(projekt)

      phases.each { |entry| build_long_tail(projekt, entry) }

      projekt.update!(imported_by_ai: true)
      projekt_import.record_created_projekt!(projekt)
    end

    ServiceResult.success(projekt: projekt)
  rescue StandardError => e
    Rails.logger.error("[ProjektImports::CreateProjektFromImportService] failed: #{e.message}\n#{e.backtrace.first(10).join("\n")}")
    Sentry.capture_exception(e, extra: { projekt_import_id: projekt_import.id, stage: "create_projekt" }) if defined?(Sentry)
    ServiceResult.failure(error: I18n.t("adm.projekts.imports.errors.create_projekt_failed", message: e.message))
  end

  private

  def create_projekt(data)
    Projekt.create!(
      name: data["title"].to_s.truncate(200),
      author: projekt_import.user,
      total_duration_start: data["projekt_start_date"].presence,
      total_duration_end: data["projekt_end_date"].presence
    )
  end

  def apply_subtitle(projekt, subtitle)
    return if subtitle.blank?

    page = projekt.page
    return if page.blank?

    page.update!(subtitle: subtitle.to_s)
  rescue StandardError => e
    projekt_import.add_warning!("subtitle: #{e.message}")
  end

  def apply_tags_and_sdgs(projekt, data)
    if data["categories"].present?
      projekt.tag_list = Array(data["categories"]).compact_blank.join(", ")
      projekt.save!
    end

    if data["sdg_codes"].present? && projekt.respond_to?(:related_sdg_list=) && sdg_goals_available?
      projekt.related_sdg_list = Array(data["sdg_codes"]).compact_blank.join(", ")
      projekt.save!
    end
  rescue StandardError => e
    projekt_import.add_warning!("tags/sdg: #{e.message}")
  end

  def sdg_goals_available?
    SDG::Goal.exists?
  rescue NameError
    false
  end

  def create_phases(projekt, phases_data)
    phases_data = Array(phases_data)
    return [] if phases_data.empty?

    phases_data.map.with_index do |phase_data, index|
      phase_class = phase_class_for(phase_data["type"])
      next nil if phase_class.blank?

      record = phase_class.create!(
        projekt: projekt,
        phase_tab_name: phase_tab_name_for(phase_data),
        start_date: phase_data["start_date"].presence,
        end_date: phase_data["end_date"].presence,
        description: phase_data["description"].presence,
        cta_button_name: phase_data["cta_button_name"].presence,
        user_status: phase_data["user_status"].presence,
        given_order: index + 1,
        active: true
      )

      { record: record, data: phase_data }
    end.compact
  end

  def create_content_blocks(projekt, blocks)
    ProjektContentBlocks::Services::CreateFromImportData.call(
      projekt: projekt,
      blocks: blocks,
      locale: projekt_import.import_locale
    )
  end

  def apply_projekt_settings(projekt, settings)
    return if settings.blank?

    settings.each do |key, value|
      next if value.nil?
      next if ALLOWED_PROJEKT_SETTINGS.exclude?(key)

      setting = projekt.projekt_settings.find_by(key: key)
      next if setting.blank?

      setting.update!(value: value.to_s)
    rescue StandardError => e
      projekt_import.add_warning!("projekt_setting(#{key}): #{e.message}")
    end
  end

  def apply_phase_settings(phase_entries, phase_settings)
    return if phase_settings.blank?

    phase_settings.each do |phase_type, settings|
      next if settings.blank?

      matching = phase_entries.select { |entry| entry[:record].type == phase_type }
      next if matching.empty?

      matching.each do |entry|
        settings.each do |key, value|
          next if value.nil?

          setting = entry[:record].settings.find_by(key: key)
          next if setting.blank?

          setting.update!(value: value.to_s)
        rescue StandardError => e
          projekt_import.add_warning!("phase_setting(#{phase_type}/#{key}): #{e.message}")
        end
      end
    end
  end

  def build_long_tail(projekt, entry)
    record = entry[:record]
    data = entry[:data]

    warn_about_missing_poll_questions(record, data)

    LONG_TAIL_BUILDERS.each do |key, builder_class|
      payload = data[key]
      next if payload.blank?

      begin
        builder_class.call(projekt: projekt, phase: record, payload: payload)
      rescue ProjektImports::Builders::BuilderError => e
        projekt_import.add_warning!("#{record.type}/#{key}: #{e.message}")
      rescue StandardError => e
        projekt_import.add_warning!("#{record.type}/#{key}: unexpected error: #{e.message}")
      end
    end
  end

  def warn_about_missing_poll_questions(record, data)
    return if !record.is_a?(ProjektPhase::VotingPhase)

    questions = ProjektImports::Builders::PollBuilder.importable_questions(data["poll_questions"])
    return if questions.any?

    projekt_import.add_warning!(
      I18n.t("adm.projekts.imports.warnings.voting_phase_without_questions",
        phase: record.title)
    )
  end

  # The AI is asked for a localized phase name, but it sometimes falls back to
  # anglicising the phase type identifier ("ProjektPhase::VotingPhase" ->
  # "Voting Phase"). Dropping such a name lets ProjektPhase#title serve the
  # translated default instead.
  def phase_tab_name_for(phase_data)
    name = phase_data["name"].to_s.strip
    return nil if name.blank?
    return nil if echoes_phase_type?(name, phase_data["type"])

    name
  end

  def echoes_phase_type?(name, type)
    return false if type.blank?

    normalized = name.downcase.gsub(/[^a-z]/, "")
    return false if normalized.blank?

    identifier = type.to_s.demodulize.underscore.delete("_")
    echoes = [
      identifier,
      identifier.delete_suffix("phase"),
      type.to_s.underscore.gsub(/[^a-z]/, "")
    ]

    echoes.include?(normalized)
  end

  def phase_class_for(type)
    return nil if type.blank?

    phase_class_map[type]
  end

  def phase_class_map
    @phase_class_map ||= ProjektPhase::ALL_PHASE_TYPES.index_with(&:safe_constantize)
  end

  def enforce_hidden_draft_state(projekt)
    HIDDEN_DRAFT_SETTINGS.each do |key|
      setting = projekt.projekt_settings.find_by(key: key)
      next if setting.blank?

      setting.update!(value: "")
    end
  end
end
