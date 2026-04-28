class Adm::MasterportalImportsController < Adm::BaseController
  before_action :load_projekt_phase, only: [:create, :status]

  def collections
    authorize [:adm, :masterportal_import], :show?
    url = params.require(:endpoint_url)

    if !allowed_host?(url)
      return render json: { error: "host_not_allowlisted" }, status: :forbidden
    end

    render json: collections_payload(url)
  rescue URI::InvalidURIError
    render json: { error: "invalid_url" }, status: :unprocessable_entity
  rescue OgcApiFeatures::Error => e
    render json: { error: "upstream", message: e.message }, status: :bad_gateway
  end

  def create
    authorize @projekt_phase, :update?, policy_class: policy_class_for(@projekt_phase)
    MasterportalImportJob.perform_later(**import_job_args)

    render json: status_payload, status: :accepted
  end

  def status
    authorize @projekt_phase, :update?, policy_class: policy_class_for(@projekt_phase)

    render json: status_payload
  end

  private

    def load_projekt_phase
      @projekt_phase = ProjektPhase.find(params[:projekt_phase_id])
    end

    def allowed_host?(url)
      host = URI.parse(url).host

      return false if host.blank?

      allowed_hosts.include?(host)
    end

    def allowed_hosts
      default = Rails.configuration.x.masterportal.oaf_endpoint.presence
      from_default = default ? [URI.parse(default).host] : []
      from_env = ENV.fetch("MASTERPORTAL_ALLOWED_HOSTS", "").split(",").map(&:strip).reject(&:empty?)

      (from_default + from_env).uniq
    end

    def collections_payload(url)
      collections = OgcApiFeatures::Client.list_collections(url)

      {
        root: {
          label: I18n.t("adm.masterportal_imports.collections.root_label"),
          children: collections.map { |c| collection_node(c) }
        }
      }
    end

    def collection_node(coll)
      {
        id: coll[:id],
        title: coll[:title],
        description: coll[:description],
        number_matched: coll[:number_matched],
        children: Array(coll[:children]).map { |c| collection_node(c) }
      }
    end

    def import_job_args
      {
        projekt_phase_id: @projekt_phase.id,
        endpoint_url: params.require(:endpoint_url),
        collection_ids: Array(params[:collection_ids]),
        create_domain_records: ActiveModel::Type::Boolean.new.cast(params[:create_domain_records]),
        triggered_by_user_id: current_user.id
      }
    end

    def status_payload
      {
        status: @projekt_phase.masterportal_import_status,
        last_imported_at: @projekt_phase.masterportal_last_imported_at,
        last_imported_count: @projekt_phase.masterportal_last_imported_count,
        error: @projekt_phase.masterportal_import_error,
        last_endpoint_url: @projekt_phase.masterportal_last_endpoint_url,
        last_collection_ids: @projekt_phase.masterportal_last_collection_ids
      }
    end
end
