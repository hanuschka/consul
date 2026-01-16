module Adm
  class SettingsController < Adm::BaseController
    def metadata
      authorize [:adm, Setting], :update?
      @breadcrumbs = [
        { name: t("adm.menu.items.home"), url: adm_root_path },
        { name: t("adm.menu.items.application") },
        { name: t(".title") }
      ]
    end

    def gdpr
      authorize [:adm, Setting], :update?
      @breadcrumbs = [
        { name: t("adm.menu.items.home"), url: adm_root_path },
        { name: t("adm.menu.items.application") },
        { name: t(".title") }
      ]
    end

    def registration
      authorize [:adm, Setting], :update?
      @breadcrumbs = [
        { name: t("adm.menu.items.home"), url: adm_root_path },
        { name: t("adm.menu.items.application") },
        { name: t(".title") }
      ]
    end
  end
end
