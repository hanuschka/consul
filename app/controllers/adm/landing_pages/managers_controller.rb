module Adm
  module LandingPages
    class ManagersController < Adm::LandingPages::BaseController
      include Admin::PendingRoleAssignable

      def index
        authorize LandingPageManager, policy_class: Adm::LandingPages::LandingPageManagerPolicy

        @pagy, @landing_page_managers = pagy(
          policy_scope(LandingPageManager, policy_scope_class: Adm::LandingPages::LandingPageManagerPolicy::Scope)
            .order(id: :desc)
        )

        @breadcrumbs = [
          { name: t("adm.landing_pages.menu.items.landing_pages"), url: adm_landing_pages_root_path, icon: "web" },
          { name: t("adm.landing_pages.menu.items.managers") }
        ]
      end

      def new
        authorize LandingPageManager, policy_class: Adm::LandingPages::LandingPageManagerPolicy

        @breadcrumbs = [
          { name: t("adm.landing_pages.menu.items.landing_pages"), url: adm_landing_pages_root_path, icon: "web" },
          { name: t("adm.landing_pages.menu.items.managers"), url: adm_landing_pages_managers_path },
          { name: t(".title") }
        ]
      end

      def destroy
        @landing_page_manager = LandingPageManager.find(params[:id])
        authorize @landing_page_manager, policy_class: Adm::LandingPages::LandingPageManagerPolicy

        @landing_page_manager.destroy!
      end

      def toggle_manage_all_landing_pages
        @landing_page_manager = LandingPageManager.find(params[:id])
        authorize @landing_page_manager, :update?, policy_class: Adm::LandingPages::LandingPageManagerPolicy

        @landing_page_manager.update!(manage_all_landing_pages: !@landing_page_manager.manage_all_landing_pages)
      end

      def search
        authorize LandingPageManager, :create?, policy_class: Adm::LandingPages::LandingPageManagerPolicy

        params[:role] = "landing_page_manager"
        @users = User.search(params[:search]).where.missing(:landing_page_manager).limit(4)
        check_pending_for_search
      end

      private

        def pending_role_type
          "LandingPageManager"
        end
    end
  end
end
