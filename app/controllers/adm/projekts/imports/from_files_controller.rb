class Adm::Projekts::Imports::FromFilesController < Adm::Projekts::BaseController
  MAX_AGGREGATE_BYTES = 45.megabytes
  ALLOWED_EXTENSIONS = %w[pdf docx odt txt md].freeze
  COMPLETED_LIST_LIMIT = 10

  STATUS_FILTERS = %w[in_progress failed completed].freeze

  before_action :authorize_create
  before_action :find_projekt_import, only: [:show, :status, :reset, :destroy]

  def index
    load_import_lists

    @breadcrumbs = [
      { name: t("adm.projekts.home.title"), url: adm_projekts_root_path },
      { name: t("adm.projekts.imports.index.title") }
    ]
  end

  def new
    @projekt_import = current_user.projekt_imports.build

    @breadcrumbs = [
      { name: t("adm.projekts.home.title"), url: adm_projekts_root_path },
      { name: t("adm.projekts.imports.index.title"), url: adm_projekts_imports_path },
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
      additional_user_instructions: params[:additional_user_instructions].presence
    )
    files.each { |file| @projekt_import.source_files.attach(file) }

    ProjektImports::FromFileJob.perform_later(@projekt_import.id)

    render json: {
      id: @projekt_import.id,
      status: @projekt_import.status,
      import_url: adm_projekts_import_path(@projekt_import)
    }
  end

  def show
    if @projekt_import.chatting? || @projekt_import.submitting? || @projekt_import.completed?
      redirect_to adm_projekts_import_chat_path(@projekt_import)
      return
    end

    if @projekt_import.abandoned?
      redirect_to new_adm_projekts_import_path
      return
    end

    @stalled = @projekt_import.stalled?
    @status_url = status_adm_projekts_import_path(@projekt_import)
    @chat_url = adm_projekts_import_chat_path(@projekt_import)

    @breadcrumbs = [
      { name: t("adm.projekts.home.title"), url: adm_projekts_root_path },
      { name: t("adm.projekts.imports.from_files.new.title"), url: new_adm_projekts_import_path },
      { name: t("adm.projekts.imports.from_files.show.title") }
    ]
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

    respond_to do |format|
      format.json { render json: { status: @projekt_import.status, new_url: new_adm_projekts_import_path } }
      format.html { redirect_to new_adm_projekts_import_path }
    end
  end

  def destroy
    authorize [:adm, :projekts, @projekt_import], :destroy?
    @projekt_import.destroy

    redirect_to adm_projekts_imports_path(status: params[:status].presence)
  end

  private

  def authorize_create
    authorize [:adm, :projekts, Projekt], :create?
  end

  def find_projekt_import
    @projekt_import = current_user.projekt_imports.find(params[:id])
  end

  def load_import_lists
    imports = policy_scope(
      ProjektImport, policy_scope_class: Adm::Projekts::ProjektImportPolicy::Scope
    ).with_attached_source_files

    @status_filter = params[:status].presence_in(STATUS_FILTERS)
    @import_counts = {
      "in_progress" => imports.in_progress.count,
      "failed" => imports.failed.count,
      "completed" => imports.completed.count
    }

    @in_progress_imports = show_status?("in_progress") ? imports.in_progress.for_listing.to_a : []
    @failed_imports = show_status?("failed") ? imports.failed.for_listing.to_a : []
    @completed_imports = show_status?("completed") ? imports.completed.for_listing.limit(COMPLETED_LIST_LIMIT).to_a : []
    @created_projekts_by_id =
      created_projekts_map(@in_progress_imports + @failed_imports + @completed_imports)
  end

  def show_status?(status)
    @status_filter.nil? || @status_filter == status
  end

  def created_projekts_map(imports)
    ids = imports.flat_map(&:created_projekt_ids).uniq
    return {} if ids.empty?

    Projekt.where(id: ids).includes(:page).index_by(&:id)
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
