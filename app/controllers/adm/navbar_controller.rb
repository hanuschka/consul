module Adm
  class NavbarController < Adm::BaseController
    def show
      authorize [:adm, :navbar]
      @breadcrumbs = [
        { name: t("adm.menu.items.home"), url: adm_root_path },
        { name: t("adm.menu.items.application") },
        { name: t("adm.menu.items.application_subitems.navbar") }
      ]
    end
  end
end
