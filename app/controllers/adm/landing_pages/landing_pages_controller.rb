module Adm
  module LandingPages
    class LandingPagesController < Adm::LandingPages::BaseController

      def index
        authorize [:adm, :landing_pages, :landing_page]
        @breadcrumbs = [
          { name: t("adm.landing_pages.menu.items.landing_pages"), icon: "web" }
        ]

        @landing_pages = policy_scope(
          ::SiteCustomization::Page,
          policy_scope_class: Adm::LandingPages::LandingPagePolicy::Scope
        ).order(:landing_nav_position)
      end

      def new
        @landing_page = ::SiteCustomization::Page.new(landing: true, status: "draft")
        authorize [:adm, :landing_pages, @landing_page], policy_class: Adm::LandingPages::LandingPagePolicy

        @breadcrumbs = [
          { name: t("adm.landing_pages.menu.items.landing_pages"), url: adm_landing_pages_root_path },
          { name: t(".title") }
        ]
      end

      def create
        @landing_page = ::SiteCustomization::Page.new(landing_page_params.merge(landing: true, status: "draft"))
        authorize [:adm, :landing_pages, @landing_page], policy_class: Adm::LandingPages::LandingPagePolicy

        if @landing_page.save
          redirect_to edit_adm_landing_pages_landing_page_path(@landing_page), notice: t(".success")
        else
          @breadcrumbs = [
            { name: t("adm.landing_pages.menu.items.landing_pages"), url: adm_landing_pages_root_path },
            { name: t("adm.landing_pages.landing_pages.new.title") }
          ]
          render :new, status: :unprocessable_entity
        end
      end

      def edit
        @landing_page = ::SiteCustomization::Page.find(params[:id])
        authorize [:adm, :landing_pages, @landing_page], policy_class: Adm::LandingPages::LandingPagePolicy

        @breadcrumbs = [
          { name: t("adm.landing_pages.menu.items.landing_pages"), url: adm_landing_pages_root_path, icon: "web" },
          { name: @landing_page.title }
        ]
      end

      def update
        @landing_page = ::SiteCustomization::Page.find(params[:id])
        authorize [:adm, :landing_pages, @landing_page], policy_class: Adm::LandingPages::LandingPagePolicy

        @landing_page.update(landing_page_params)
        flash.now[:success] = t(".success")

        if params[:respond_with].present?
          render turbo_stream: turbo_stream.replace(
            params[:respond_with],
            partial: params[:respond_with],
            locals: { landing_page: @landing_page }
          )
        end
      end

      def toggle_active
        @landing_page = ::SiteCustomization::Page.find(params[:id])
        authorize [:adm, :landing_pages, @landing_page], :update?, policy_class: Adm::LandingPages::LandingPagePolicy

        @landing_page.update!(status: landing_page_params[:status])
      end

      def reorder
        authorize [:adm, :landing_pages, :landing_page], :index?

        ::SiteCustomization::Page.order_landing_pages(params[:ordered_list])
        head :ok
      end

      private

        def landing_page_params
          params.require(:site_customization_page).permit(
            :title, :status, :slug,
            :landing_hide_title_and_subtitle, :landing_hide_all_top_nav_links, :landing_show_projekts_overview,
            :landing_site_logo_follow_to_landing_page, :landing_navigation_link_color,
            :landing_site_logo_for_transparent_background, :landing_site_logo_for_white_background,
            :landing_desktop_header_image, :landing_mobile_header_image,
            landing_page_manager_ids: []
          )
        end
    end
  end
end
