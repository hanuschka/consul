class Adm::Projekts::Imports::FromUrlsController < Adm::Projekts::BaseController
  before_action :authorize_create

  def new
    @projekt_import = current_user.projekt_imports.build(source_kind: "url")

    @breadcrumbs = [
      { name: t("adm.projekts.home.title"), url: adm_projekts_root_path },
      { name: t("adm.projekts.imports.index.title"), url: adm_projekts_imports_path },
      { name: t("adm.projekts.imports.from_urls.new.title") }
    ]
  end

  def create
    source_url = params[:source_url].to_s.strip

    if source_url.blank?
      flash[:error] = t("adm.projekts.imports.errors.url.blank")

      redirect_to new_adm_projekts_imports_from_url_path
      return
    end

    projekt_import = current_user.projekt_imports.create!(
      source_kind: "url",
      source_url: source_url,
      status: "pending",
      title_image_mode: "none",
      additional_user_instructions: params[:additional_user_instructions].presence
    )

    ProjektImports::FromUrlJob.perform_later(projekt_import.id)

    redirect_to adm_projekts_import_path(projekt_import)
  end

  private

    def authorize_create
      authorize [:adm, :projekts, Projekt], :create?
    end
end
