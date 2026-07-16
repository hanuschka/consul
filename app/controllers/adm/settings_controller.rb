module Adm
  class SettingsController < Adm::BaseController
    def metadata
      authorize [:adm, Setting], :update?
      @breadcrumbs = [
        { name: t("adm.menu.items.application"), icon: "desktop_windows" },
        { name: t(".title") }
      ]
    end

    def gdpr
      authorize [:adm, Setting], :update?
      @breadcrumbs = [
        { name: t("adm.menu.items.application"), icon: "desktop_windows" },
        { name: t(".title") }
      ]
    end

    def registration
      authorize [:adm, Setting], :update?
      @breadcrumbs = [
        { name: t("adm.menu.items.application"), icon: "desktop_windows" },
        { name: t(".title") }
      ]
    end

    def file_settings
      authorize [:adm, Setting], :update?
      @breadcrumbs = [
        { name: t("adm.menu.items.files"), icon: "folder" },
        { name: t(".title") }
      ]
    end
  end
end
