# The review step for an import the AI never touched. A copied Consul projekt
# arrives as a finished structure, so what the admin is asked before it is
# built is a plain form rather than a conversation — which is also what keeps
# this source working on an instance with the AI switched off.
class Adm::Projekts::Imports::ReviewsController < Adm::Projekts::BaseController
  include Adm::Projekts::ProjektImportScoped

  before_action :authorize_create
  before_action :find_projekt_import
  before_action :ensure_review_step!

  def show
    @overlay = @projekt_import.overlay
    @status_url = status_adm_projekts_import_path(@projekt_import)
    @execute_url = execute_adm_projekts_import_review_path(@projekt_import)
    @autosave_url = adm_projekts_import_review_path(@projekt_import)

    @breadcrumbs = [
      { name: t("adm.projekts.home.title"), url: adm_projekts_root_path },
      { name: t("adm.projekts.imports.index.title"), url: adm_projekts_imports_path },
      { name: t("adm.projekts.imports.reviews.show.title") }
    ]
  end

  def update
    @projekt_import.apply_overlay!(overlay_params)

    respond_to do |format|
      format.html do
        redirect_to adm_projekts_import_review_path(@projekt_import),
          notice: t("adm.projekts.imports.reviews.saved")
      end
      format.json { head :ok }
    end
  end

  def execute
    @projekt_import.apply_overlay!(overlay_params)
    ProjektImports::ExecuteImportJob.perform_later(@projekt_import.id)

    redirect_to adm_projekts_import_path(@projekt_import)
  end

  private

    def authorize_create
      authorize [:adm, :projekts, Projekt], :create?
    end

    def find_projekt_import
      @projekt_import = visible_projekt_imports.find(params[:import_id])
    end

    # An AI-negotiated import belongs in the chat; a finished one has nothing
    # left to review.
    def ensure_review_step!
      if @projekt_import.ai_negotiated?
        redirect_to adm_projekts_import_chat_path(@projekt_import)
        return
      end

      return if !@projekt_import.completed?
      return if @projekt_import.projekt_id.blank?

      redirect_to projekt_path(@projekt_import.projekt_id)
    end

    def overlay_params
      {
        "name" => params[:name].to_s.strip,
        "starts_at" => params[:starts_at].presence,
        "ends_at" => params[:ends_at].presence,
        "phase_names" => submitted_phase_names
      }
    end

    # The form posts one field per phase keyed by the source row id, which is
    # the handle the overlay and the copier's id map both use. The rest of the
    # entry (type, dates) is display context and passes through untouched.
    def submitted_phase_names
      submitted = params[:phase_names] || {}

      @projekt_import.overlay["phase_names"].to_a.map do |entry|
        name = submitted[entry["source_id"].to_s]

        entry.merge("name" => (name.presence || entry["name"]).to_s.strip)
      end
    end
end
