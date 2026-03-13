module Adm
  class NavbarController < Adm::BaseController
    def show
      authorize [:adm, :navbar]

      @navbar_items = NavbarItem.top_level

      @breadcrumbs = [
        { name: t("adm.menu.items.application"), icon: "desktop_windows" },
        { name: t("adm.menu.items.application_subitems.navbar") }
      ]
    end
  end
end
