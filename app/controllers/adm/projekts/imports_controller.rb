class Adm::Projekts::ImportsController < Adm::Projekts::BaseController
  include Adm::Projekts::ProjektImportScoped

  STATUS_FILTERS = %w[in_progress failed completed].freeze

  before_action :authorize_create
  before_action :find_projekt_import,
    only: [:show, :status, :source_text, :reset, :retry_import, :destroy]

  def index
    load_import_lists

    @breadcrumbs = [
      { name: t("adm.projekts.home.title"), url: adm_projekts_root_path },
      { name: t("adm.projekts.imports.index.title") }
    ]
  end

  def show
    if @projekt_import.chatting? || @projekt_import.submitting? || @projekt_import.completed?
      redirect_to helpers.import_review_path(@projekt_import)
      return
    end

    if @projekt_import.abandoned?
      redirect_to helpers.import_source_new_path(@projekt_import)
      return
    end

    @stalled = @projekt_import.stalled?
    @status_url = status_adm_projekts_import_path(@projekt_import)
    @review_url = helpers.import_review_path(@projekt_import)
    @source_new_url = helpers.import_source_new_path(@projekt_import)

    @breadcrumbs = [
      { name: t("adm.projekts.home.title"), url: adm_projekts_root_path },
      { name: t("adm.projekts.imports.index.title"), url: adm_projekts_imports_path },
      { name: t("adm.projekts.imports.show.title") }
    ]
  end

  def status
    render json: status_payload
  end

  # What the import actually read, shown verbatim. The chat reports the model's
  # conclusions; this is the only place the administrator can check them against
  # the material — and the only way an instruction hidden in a fetched page
  # becomes visible to the person approving the projekt.
  def source_text
    @source_label = helpers.import_source_description(@projekt_import)
    @back_url = helpers.import_review_path(@projekt_import)

    @breadcrumbs = [
      { name: t("adm.projekts.home.title"), url: adm_projekts_root_path },
      { name: t("adm.projekts.imports.index.title"), url: adm_projekts_imports_path },
      { name: t("adm.projekts.imports.source_text.title") }
    ]
  end

  def reset
    @projekt_import.mark_abandoned!
    new_url = helpers.import_source_new_path(@projekt_import)

    respond_to do |format|
      format.json { render json: { status: @projekt_import.status, new_url: new_url } }
      format.html { redirect_to new_url }
    end
  end

  # The source is still on the record in every case — the files, the address or
  # the fetched bundle — so a transient extraction or model failure is recovered
  # by re-running the same job rather than by asking for it all again.
  def retry_import
    if !@projekt_import.retryable?
      flash[:alert] = t("adm.projekts.imports.errors.not_retryable")

      redirect_to adm_projekts_import_path(@projekt_import)
      return
    end

    @projekt_import.reset_for_retry!
    ProjektImports::DispatchSourceJob.call(projekt_import: @projekt_import)

    redirect_to adm_projekts_import_path(@projekt_import)
  end

  def destroy
    authorize [:adm, :projekts, @projekt_import], :destroy?
    @projekt_import.destroy

    redirect_to adm_projekts_imports_path(
      status: params[:status].presence, mine: params[:mine].presence
    )
  end

  private

    def authorize_create
      authorize [:adm, :projekts, Projekt], :create?
    end

    def find_projekt_import
      @projekt_import = visible_projekt_imports.find(params[:id])
    end

    def status_payload
      payload = {
        status: @projekt_import.status,
        submit_stage: @projekt_import.submit_stage,
        warnings: @projekt_import.warnings
      }

      if @projekt_import.chatting?
        payload[:review_url] = helpers.import_review_path(@projekt_import)
      end

      return payload if !@projekt_import.failed?

      payload
        .merge(error: @projekt_import.error_message, failure_stage: @projekt_import.failure_stage)
        .merge(retry_payload)
    end

    def retry_payload
      return {} if !@projekt_import.retryable?

      { retry_url: retry_adm_projekts_import_path(@projekt_import) }
    end

    def load_import_lists
      imports = listed_imports.with_attached_source_files

      @status_filter = params[:status].presence_in(STATUS_FILTERS)
      @own_imports_only = own_imports_only?
      @shows_every_owner = Adm::Projekts::ProjektImportPolicy.all_imports_permitted?(current_user)
      @import_counts = {
        "in_progress" => imports.in_progress.count,
        "failed" => imports.failed.count,
        "completed" => imports.completed.count
      }

      @imports = filtered_imports(imports).includes(:user).for_listing.page(params[:page]).per(20)
      @created_projekts_by_id = created_projekts_map(@imports)
    end

    # The list carries every import on the instance for the people who may see
    # them all, which buries your own half-finished one behind colleagues' rows;
    # the counts follow the same narrowing so the chips keep matching the list.
    def listed_imports
      return visible_projekt_imports.where(user: current_user) if own_imports_only?

      visible_projekt_imports
    end

    def own_imports_only?
      params[:mine].present?
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
end
