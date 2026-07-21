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

    uploaded_files = Array(params[:files])
    geoserver_collection_ids = Array(params[:collection_ids])

    if uploaded_files.blank? && geoserver_collection_ids.blank?
      return render json: { error: "nothing_selected" }, status: :unprocessable_entity
    end

    file_errors = validate_uploaded_files(uploaded_files)

    if file_errors.any?
      return render json: { errors: file_errors }, status: :unprocessable_entity
    end

    uploaded_collection_ids = create_file_collections(uploaded_files)

    MasterportalImportJob.perform_later(
      **import_job_args(geoserver_collection_ids, uploaded_collection_ids)
    )

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
      default = Rails.application.secrets.dig(:masterportal, :oaf_endpoint).presence
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

    def import_job_args(geoserver_collection_ids, uploaded_collection_ids)
      {
        projekt_phase_id: @projekt_phase.id,
        endpoint_url: params[:endpoint_url].presence,
        collection_ids: geoserver_collection_ids,
        uploaded_collection_ids: uploaded_collection_ids,
        create_domain_records: create_domain_records?,
        triggered_by_user_id: current_user.id
      }
    end

    def create_domain_records?
      ActiveModel::Type::Boolean.new.cast(params[:create_domain_records])
    end

    def validate_uploaded_files(files)
      files.each_with_index.filter_map do |file, index|
        Masterportal::GeojsonFileFeatures.validate_upload!(file)
        nil
      rescue Masterportal::GeojsonFileFeatures::InvalidFile => e
        { index: index, filename: file.original_filename, reason: e.reason }
      end
    end

    def create_file_collections(files)
      requested_names = Array(params[:file_names])

      files.each_with_index.map do |file, index|
        build_file_collection(file, requested_names[index]).id
      end
    end

    def build_file_collection(file, requested_name)
      base_name = File.basename(file.original_filename.to_s, ".*")
      display_name = requested_name.to_s.strip.presence || base_name
      collection_id = display_name.parameterize.presence || base_name.parameterize.presence || "datei"

      collection =
        @projekt_phase.masterportal_collections.find_or_initialize_by(collection_id: collection_id)
      collection.name = display_name
      collection.source = "file"
      collection.endpoint_url = "file://#{file.original_filename}"
      collection.create_domain_records = create_domain_records?
      collection.save!

      collection.geojson_file.attach(
        io: file.tempfile,
        filename: file.original_filename,
        content_type: "application/geo+json"
      )

      collection
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
