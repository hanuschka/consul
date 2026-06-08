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

      phases.each { |entry| build_long_tail(projekt, entry) }

      projekt.update!(imported_by_ai: true)
      projekt_import.update!(projekt_id: projekt.id)
    end

    ServiceResult.success(projekt: projekt)
  rescue StandardError => e
    Rails.logger.error("[ProjektImports::CreateProjektFromImportService] failed: #{e.message}\n#{e.backtrace.first(10).join("\n")}")
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

    if data["sdg_codes"].present? && projekt.respond_to?(:related_sdg_list=)
      projekt.related_sdg_list = Array(data["sdg_codes"]).compact_blank.join(", ")
      projekt.save!
    end
  rescue StandardError => e
    projekt_import.add_warning!("tags/sdg: #{e.message}")
  end

  def create_phases(projekt, phases_data)
    phases_data = Array(phases_data)
    return [] if phases_data.empty?

    phases_data.map.with_index do |phase_data, index|
      type = phase_data["type"]
      next nil if type.blank? || ProjektPhase::ALL_PHASE_TYPES.exclude?(type)

      record = type.constantize.create!(
        projekt: projekt,
        phase_tab_name: phase_data["name"].presence,
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
    Array(blocks).each_with_index do |block, position|
      body = block["html"].presence || block["content_data"].to_s
      next if body.blank?

      projekt.content_blocks.create!(
        name: "custom",
        key: "projekt_content_block_#{projekt.id}_#{position + 1}_#{DateTime.now.to_i}",
        body: body,
        locale: I18n.locale.to_s,
        position: position + 1
      )
    rescue ActiveRecord::RecordInvalid => e
      raise "content_block(##{position + 1}): #{e.message}"
    end
  end

  def apply_projekt_settings(projekt, settings)
    blocked_keys = %w[projekt_feature.main.activate projekt_feature.general.show_in_navigation]
    return if settings.blank?

    settings.each do |key, value|
      next if value.nil?
      next if blocked_keys.include?(key)

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
end
