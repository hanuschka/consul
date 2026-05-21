class Adm::MasterportalImportPanelComponent < ApplicationComponent
  RESOURCE_NAME_KEYS = {
    "ProjektPhase::ProposalPhase" => ".resource_names.proposals",
    "ProjektPhase::BudgetPhase" => ".resource_names.budget_investments",
    "ProjektPhase::PointOfInterestPhase" => ".resource_names.point_of_interest_pins"
  }.freeze

  SUPPORTED_PHASE_TYPES = RESOURCE_NAME_KEYS.keys.freeze

  def initialize(projekt_phase:, embedded: false)
    @projekt_phase = projekt_phase
    @embedded = embedded
  end

  def embedded?
    @embedded
  end

  def default_endpoint_url
    Rails.application.secrets.dig(:masterportal, :oaf_endpoint)
  end

  def supports_domain_records?
    SUPPORTED_PHASE_TYPES.include?(@projekt_phase.type)
  end

  def resource_name
    key = RESOURCE_NAME_KEYS[@projekt_phase.type]
    return nil if key.blank?

    t(key)
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

  PROGRESS_COUNT_TOKEN = "{{count}}".freeze

  def progress_count_template
    t(".progress.processed", count: PROGRESS_COUNT_TOKEN)
  end

  def progress_count_initial
    progress_count_template.sub(PROGRESS_COUNT_TOKEN, "0")
  end

  def status_summary
    case @projekt_phase.masterportal_import_status
    when "running"
      t(".status.running")
    when "success"
      imported_at = @projekt_phase.masterportal_last_imported_at
      formatted_at = imported_at ? I18n.l(imported_at, format: :short) : ""
      t(".status.success", at: formatted_at, count: @projekt_phase.masterportal_last_imported_count.to_i)
    when "failed"
      t(".status.failed")
    else
      t(".status.pending")
    end
  end

  def status_icon
    case @projekt_phase.masterportal_import_status
    when "running"
      "progress_activity"
    when "success"
      "check_circle"
    when "failed"
      "error"
    else
      "schedule"
    end
  end

  private

    attr_reader :projekt_phase
end
