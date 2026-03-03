module Adm
  class HomeController < Adm::BaseController
    def show
      authorize [:adm, :home]
      @breadcrumbs = [
        { name: t("adm.menu.items.home") }
      ]
    end
  end
end
