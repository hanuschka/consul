module Adm
  class SettingsController < Adm::BaseController
    def update
      authorize [:adm, Setting], :update?

      @setting = Setting.find(params[:id])
      if @setting.update(setting_params)
        flash.now[:success] = t(".success")
      end
    end

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

    private

      def setting_params
        params.require(:setting).permit(:value)
      end
  end
end
