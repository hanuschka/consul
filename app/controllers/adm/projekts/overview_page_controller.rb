class Adm::Projekts::OverviewPageController < Adm::Projekts::BaseController
  def navigation
    authorize [:adm, Setting], :update?

    @breadcrumbs = [
      { name: t("adm.projekts.menu.items.projekts"), url: adm_projekts_root_path },
      { name: t("adm.projekts.menu.items.overview_page") }
    ]
  end

  def footer
    authorize [:adm, Setting], :update?

    @breadcrumbs = [
      { name: t("adm.projekts.menu.items.projekts"), url: adm_projekts_root_path },
      { name: t("adm.projekts.menu.items.overview_page") }
    ]
  end
end
