class Adm::MasterportalIntegrationComponent < ApplicationComponent
  PROGRESS_COUNT_TOKEN = "{{count}}".freeze

  def initialize(projekt_phase:, masterportal_pins_count:)
    @projekt_phase = projekt_phase
    @masterportal_pins_count = masterportal_pins_count.to_i
  end

  def has_pins?
    @masterportal_pins_count.positive?
  end

  def projekt_phase_title
    @projekt_phase.title
  end

  def endpoints_data
    {
      collections_url: helpers.collections_adm_masterportal_imports_path,
      create_url: helpers.adm_masterportal_imports_path,
      status_url: helpers.status_adm_masterportal_imports_path,
      projekt_phase_id: @projekt_phase.id
    }
  end

  def initial_status
    {
      status: @projekt_phase.masterportal_import_status,
      last_imported_at: @projekt_phase.masterportal_last_imported_at,
      last_imported_count: @projekt_phase.masterportal_last_imported_count,
      error: @projekt_phase.masterportal_import_error
    }
  end

  def progress_count_template
    I18n.t(
      "components.adm.masterportal_import_panel_component.progress.processed",
      count: PROGRESS_COUNT_TOKEN
    )
  end

  def status_summary
    case @projekt_phase.masterportal_import_status
    when "running"
      I18n.t("components.adm.masterportal_import_panel_component.status.running")
    when "success"
      imported_at = @projekt_phase.masterportal_last_imported_at
      formatted_at = imported_at ? I18n.l(imported_at, format: :short) : ""
      I18n.t(
        "components.adm.masterportal_import_panel_component.status.success",
        at: formatted_at,
        count: @projekt_phase.masterportal_last_imported_count.to_i
      )
    when "failed"
      I18n.t("components.adm.masterportal_import_panel_component.status.failed")
    else
      I18n.t("components.adm.masterportal_import_panel_component.status.pending")
    end
  end

  def status_icon
    case @projekt_phase.masterportal_import_status
    when "running" then "progress_activity"
    when "success" then "check_circle"
    when "failed" then "error"
    else "schedule"
    end
  end

  def summary_frame_id
    helpers.dom_id(@projekt_phase, :masterportal_pins_summary)
  end

  def summary_frame_src
    helpers.masterportal_pins_summary_adm_projekts_phase_path(@projekt_phase)
  end

  def summary_loading_label
    I18n.t("adm.projekts.phases.masterportal_pins_summary.loading")
  end

  attr_reader :projekt_phase
end
