module Adm
  class LandingPagesController < Adm::BaseController
    include Translatable

    def index
      authorize [:adm, :landing_page]
      @breadcrumbs = [
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
        { name: t("adm.menu.items.application_subitems.landing_pages"), url: adm_landing_pages_path },
        { name: t(".title") }
      ]
    end

    def update
      @landing_page = ::SiteCustomization::Page.find(params[:id])
      authorize [:adm, @landing_page], policy_class: Adm::LandingPagePolicy

      if @landing_page.update(landing_page_params)
        flash.now[:success] = t(".success")
      end
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
        params.require(:site_customization_page).permit(
          :status, :slug,
          :landing_hide_title_and_subtitle, :landing_hide_all_top_nav_links, :landing_show_projekts_overview,
          :landing_site_logo_follow_to_landing_page, :landing_navigation_link_color,
          :landing_site_logo_for_transparent_background, :landing_site_logo_for_white_background,
          :landing_desktop_header_image, :landing_mobile_header_image,
          translation_params(::SiteCustomization::Page)
        )
      end
  end
end
