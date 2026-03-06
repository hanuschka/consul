module Adm
  class HomepageController < Adm::BaseController
    def show
      authorize [:adm, :homepage]
      @breadcrumbs = [
        { name: t("adm.menu.items.application") },
        { name: t("adm.menu.items.application_subitems.homepage") }
      ]
    end
  end
end
