module Adm
  class LandingPagesController < Adm::BaseController
    def index
      authorize [:adm, :landing_page]
      @breadcrumbs = [
        { name: t("adm.menu.items.home"), url: adm_root_path },
        { name: t("adm.menu.items.application_subitems.landing_pages") }
      ]

      @landing_pages = policy_scope(
        ::SiteCustomization::Page,
        policy_scope_class: Adm::LandingPagePolicy::Scope
      ).order(:landing_nav_position)
    end

    def edit
      @landing_page = ::SiteCustomization::Page.find(params[:id])
      authorize [:adm, @landing_page], policy_class: Adm::LandingPagePolicy

      @breadcrumbs = [
        { name: t("adm.menu.items.home"), url: adm_root_path },
        { name: t("adm.menu.items.application_subitems.landing_pages"), url: adm_landing_pages_path },
        { name: t(".title") }
      ]
    end

    def update
      @landing_page = ::SiteCustomization::Page.find(params[:id])
      authorize [:adm, @landing_page], policy_class: Adm::LandingPagePolicy

      @attribute = landing_page_params[:attribute]
      @value = landing_page_params[:value]

      @landing_page.update!(@attribute => @value)
    end

    def toggle_active
      @landing_page = ::SiteCustomization::Page.find(params[:id])
      authorize [:adm, @landing_page], :update?, policy_class: Adm::LandingPagePolicy

      @landing_page.update!(status: landing_page_params[:status])
    end

    def reorder
      authorize [:adm, :landing_page], :index?

      ::SiteCustomization::Page.order_landing_pages(params[:ordered_list])
      head :ok
    end

    private

      def landing_page_params
        params.require(:site_customization_page).permit(:attribute, :value, :status)
      end
  end
end
