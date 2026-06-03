module Adm
  class FeaturesController < Adm::BaseController
    def show
      authorize [:adm, Setting], :update?
      @breadcrumbs = [
        { name: t("adm.menu.items.application"), icon: "desktop_windows" },
        { name: t(".title") }
      ]
    end
  end
end
