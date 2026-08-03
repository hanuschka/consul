class Adm::Projekts::Imports::FromFilesController < Adm::Projekts::BaseController
  MAX_AGGREGATE_BYTES = 500.megabytes
  ALLOWED_EXTENSIONS = %w[pdf docx odt txt md].freeze

  STATUS_FILTERS = %w[in_progress failed completed].freeze

  before_action :authorize_create
  before_action :find_projekt_import, only: [:show, :status, :reset, :destroy]

  def index
    load_import_lists
    @missing_tools = ProjektImports::RequiredTools.missing

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
    payload = { status: @projekt_import.status, warnings: @projekt_import.warnings }

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

    @imports = filtered_imports(imports).for_listing.page(params[:page]).per(20)
    @created_projekts_by_id = created_projekts_map(@imports)
  end

  def filtered_imports(imports)
    case @status_filter
    when "in_progress" then imports.in_progress
    when "failed" then imports.failed
    when "completed" then imports.completed
    else imports.where.not(status: "abandoned")
    end
  end

  def created_projekts_map(imports)
    ids = imports.flat_map { |import| import.created_projekt_ids + [import.projekt_id] }.compact.uniq
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
