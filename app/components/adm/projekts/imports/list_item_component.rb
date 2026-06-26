class Adm::Projekts::Imports::ListItemComponent < ApplicationComponent
  with_collection_parameter :projekt_import

  STATE_ICONS = {
    analyzing: "hourglass_top",
    stalled: "warning",
    chatting: "forum",
    submitting: "sync",
    failed: "error",
    completed: "check_circle"
  }.freeze

  def initialize(projekt_import:, created_projekts_by_id: {})
    @projekt_import = projekt_import
    @created_projekts_by_id = created_projekts_by_id
  end

  private

  attr_reader :projekt_import, :created_projekts_by_id

  def display_state
    return :stalled if projekt_import.stalled?
    return :analyzing if projekt_import.analyzing?

    projekt_import.status.to_sym
  end

  def state_label
    I18n.t("adm.projekts.imports.list.states.#{display_state}")
  end

  def state_icon
    STATE_ICONS.fetch(display_state, "description")
  end

  def state_modifier
    "-#{display_state}"
  end

  TITLE_TRUNCATE = 40

  def file_names
    @file_names ||= projekt_import.source_files.map { |file| file.filename.to_s }
  end

  def files_summary
    return I18n.t("adm.projekts.imports.list.no_files") if file_names.empty?
    return file_names.first.truncate(TITLE_TRUNCATE) if file_names.size == 1

    I18n.t("adm.projekts.imports.list.files_summary",
      first: file_names.first.truncate(36), count: file_names.size - 1)
  end

  def files_full
    file_names.join(", ")
  end

  def show_files_tooltip?
    file_names.present? && files_full != files_summary
  end

  def created_label
    I18n.t("adm.projekts.imports.list.created_at", time: helpers.l(projekt_import.created_at, format: :short))
  end

  def show_finished?
    display_state.in?(%i[completed failed])
  end

  def finished_label
    I18n.t("adm.projekts.imports.list.finished_at", time: helpers.l(projekt_import.updated_at, format: :short))
  end

  def error_preview
    projekt_import.error_message.to_s.truncate(160)
  end

  def show_error?
    display_state.in?(%i[failed stalled]) && error_preview.present?
  end

  def show_image_failed_note?
    display_state == :completed && projekt_import.image_failed?
  end

  def created_projekts
    ids = (projekt_import.created_projekt_ids + [projekt_import.projekt_id]).compact.uniq
    ids.filter_map { |id| created_projekts_by_id[id] }
  end

  def show_created_projekts?
    created_projekts.any?
  end

  def projekt_subtitle(projekt)
    projekt.page&.subtitle
  end

  def projekt_image_variant(projekt)
    return nil if !projekt.image&.attached?

    projekt.image.variant(:thumb2)
  rescue StandardError
    nil
  end

  def primary_action_label
    key =
      case display_state
      when :completed then "open_chat"
      when :failed, :stalled then "open_details"
      else "continue"
      end

    I18n.t("adm.projekts.imports.list.actions.#{key}")
  end

  def primary_action_url
    if display_state.in?(%i[chatting submitting completed])
      helpers.adm_projekts_import_chat_path(projekt_import)
    else
      helpers.adm_projekts_import_path(projekt_import)
    end
  end

  def delete_url
    helpers.adm_projekts_import_path(projekt_import)
  end
end
