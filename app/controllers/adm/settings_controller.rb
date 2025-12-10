module Adm
  class SettingsController < Adm::BaseController
    def update
      authorize [:adm, Setting], :update?

      @setting = Setting.find(params[:id])
      @setting.update!(setting_params)
    end

    def metadata
      authorize [:adm, Setting], :update?
      @breadcrumbs = [
        { name: t("adm.menu.items.home"), url: adm_root_path },
        { name: t("adm.menu.items.application") },
        { name: t("adm.menu.items.application_subitems.metadata_settings") }
      ]
    end

    def gdpr
      authorize [:adm, Setting], :update?
      @breadcrumbs = [
        { name: t("adm.menu.items.home"), url: adm_root_path },
        { name: t("adm.menu.items.application") },
        { name: t("adm.menu.items.application_subitems.gdpr_settings") }
      ]
    end

    private

      def setting_params
        params.require(:setting).permit(:value)
      end
  end
end
