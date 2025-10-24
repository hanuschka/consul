module Adm
  class LandingPagesController < Adm::BaseController
    def index
      authorize [:adm, :landing_page]
      skip_policy_scope
      @breadcrumbs = [
        { name: t("adm.menu.items.home"), url: adm_root_path },
        { name: t("adm.menu.items.application") },
        { name: t("adm.menu.items.application_subitems.landing_pages") }
      ]
    end
  end
end
