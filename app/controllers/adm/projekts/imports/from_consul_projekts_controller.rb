class Adm::Projekts::Imports::FromConsulProjektsController < Adm::Projekts::BaseController
  before_action :authorize_create

  def new
    @projekt_import = current_user.projekt_imports.build(source_kind: "consul_projekt")

    @breadcrumbs = [
      { name: t("adm.projekts.home.title"), url: adm_projekts_root_path },
      { name: t("adm.projekts.imports.index.title"), url: adm_projekts_imports_path },
      { name: t("adm.projekts.imports.from_consul_projekts.new.title") }
    ]
  end

  def create
    source_url = params[:source_url].to_s.strip

    if source_url.blank?
      flash[:error] = t("adm.projekts.imports.errors.consul_projekt.blank")

      redirect_to new_adm_projekts_imports_from_consul_projekt_path
      return
    end

    projekt_import = current_user.projekt_imports.create!(
      source_kind: "consul_projekt",
      source_url: source_url,
      status: "pending",
      title_image_mode: "none"
    )

    ProjektImports::FromConsulProjektJob.perform_later(projekt_import.id)

    redirect_to adm_projekts_import_path(projekt_import)
  end

  private

    def authorize_create
      authorize [:adm, :projekts, Projekt], :create?
    end
end
