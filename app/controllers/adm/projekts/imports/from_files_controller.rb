class Adm::Projekts::Imports::FromFilesController < Adm::Projekts::BaseController
  MAX_AGGREGATE_BYTES = 45.megabytes
  ALLOWED_EXTENSIONS = %w[pdf docx odt txt md].freeze

  before_action :authorize_create
  before_action :find_projekt_import, only: [:show, :status, :reset]

  def new
    @projekt_import = current_user.projekt_imports.build

    @breadcrumbs = [
      { name: t("adm.projekts.home.title"), url: adm_projekts_root_path },
      { name: t(".title") }
    ]
  end

  def create
    files = Array(params[:files]).reject(&:blank?)

    if files.empty?
      respond_with_error(t("adm.projekts.imports.errors.no_files"))
      return
    end

    if files.sum { |f| f.size.to_i } > MAX_AGGREGATE_BYTES
      respond_with_error(t("adm.projekts.imports.errors.too_large"))
      return
    end

    invalid = files.find { |f| !allowed_extension?(f) }
    if invalid
      respond_with_error(t("adm.projekts.imports.errors.unsupported_type", filename: invalid.original_filename))
      return
    end

    @projekt_import = current_user.projekt_imports.create!(
      status: "pending",
      generate_image: ActiveModel::Type::Boolean.new.cast(params[:generate_image]),
      additional_user_instructions: params[:additional_user_instructions].presence
    )
    files.each { |file| @projekt_import.source_files.attach(file) }

    ProjektImports::FromFileJob.perform_later(@projekt_import.id)

    render json: {
      id: @projekt_import.id,
      status: @projekt_import.status,
      status_url: status_adm_projekts_import_path(@projekt_import)
    }
  end

  def show
    redirect_to adm_projekts_import_chat_path(@projekt_import) if @projekt_import.chatting?
  end

  def status
    payload = { status: @projekt_import.status }

    payload[:chat_url] = adm_projekts_import_chat_path(@projekt_import) if @projekt_import.chatting?

    if @projekt_import.completed? && @projekt_import.projekt_id.present?
      payload[:projekt_id] = @projekt_import.projekt_id
      payload[:redirect_path] = projekt_path(@projekt_import.projekt_id)
    end

    payload[:error] = @projekt_import.error_message if @projekt_import.failed?

    render json: payload
  end

  def reset
    @projekt_import.mark_abandoned!

    render json: { status: @projekt_import.status, new_url: new_adm_projekts_import_path }
  end

  private

  def authorize_create
    authorize [:adm, :projekts, Projekt], :create?
  end

  def find_projekt_import
    @projekt_import = current_user.projekt_imports.find(params[:id])
  end

  def allowed_extension?(file)
    ext = File.extname(file.original_filename).delete(".").downcase
    ALLOWED_EXTENSIONS.include?(ext)
  end

  def respond_with_error(message)
    respond_to do |format|
      format.json { render json: { error: message }, status: :unprocessable_entity }
      format.html do
        flash[:error] = message
        redirect_to new_adm_projekts_import_path
      end
    end
  end
end
