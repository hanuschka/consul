module Adm
  module LandingPages
    class LandingPagesController < Adm::LandingPages::BaseController
      HEX_COLOR_REGEX = /\A#[0-9a-fA-F]{6}\z/
      DEFAULT_NAVIGATION_LINK_COLOR = "#000000".freeze

      def new
        @landing_page = ::SiteCustomization::Page.new(landing: true, status: "draft")
        authorize [:adm, :landing_pages, @landing_page], policy_class: Adm::LandingPages::LandingPagePolicy

        @breadcrumbs = [
          { name: t("adm.landing_pages.menu.items.landing_pages"), icon: "web", url: adm_landing_pages_root_path },
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
            { name: t("adm.landing_pages.menu.items.landing_pages"), icon: "web", url: adm_landing_pages_root_path },
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

        if remove_attachment_request?
          @landing_page.public_send(params[:attribute]).purge
        else
          @landing_page.update(landing_page_params)
        end
        flash.now[:success] = t(".success")

        if params[:respond_with].present?
          render turbo_stream: turbo_stream.replace(
            params[:respond_with],
            partial: params[:respond_with],
            locals: { landing_page: @landing_page }
          )
        end
      end

      def destroy
        @landing_page = ::SiteCustomization::Page.landing.find(params[:id])
        authorize [:adm, :landing_pages, @landing_page], policy_class: Adm::LandingPages::LandingPagePolicy

        if @landing_page.safe_to_destroy?
          @landing_page.destroy!
          redirect_to adm_landing_pages_root_path, notice: t(".success")
        else
          redirect_to adm_landing_pages_root_path, alert: t(".cannot_destroy")
        end
      end

      def toggle_active
        @landing_page = ::SiteCustomization::Page.find(params[:id])
        authorize [:adm, :landing_pages, @landing_page], :update?, policy_class: Adm::LandingPages::LandingPagePolicy

        @landing_page.update!(status: landing_page_params[:status])
      end

      def update_navigation_link_color
        @landing_page = ::SiteCustomization::Page.find(params[:id])
        authorize [:adm, :landing_pages, @landing_page], :update?, policy_class: Adm::LandingPages::LandingPagePolicy

        raw_color = params[:color].to_s.strip
        new_color = raw_color.presence || DEFAULT_NAVIGATION_LINK_COLOR

        unless new_color.match?(HEX_COLOR_REGEX)
          render json: { ok: false, errors: ["Invalid color format"] },
                 status: :unprocessable_entity
          return
        end

        @landing_page.update!(landing_navigation_link_color: new_color)

        render json: { ok: true, color: new_color }
      end

      def reorder
        authorize [:adm, :landing_pages, :landing_page], :index?

        ::SiteCustomization::Page.order_landing_pages(params[:tree].map { |item| item[:id] })
        head :ok
      end

      private

        def remove_attachment_request?
          return false unless params[:remove_attachment] == "1" && params[:attribute].present?

          ::SiteCustomization::Page.reflect_on_attachment(params[:attribute].to_sym).present?
        end

        def landing_page_params
          params.require(:site_customization_page).permit(
            :title, :header_title, :subtitle, :status, :slug,
            :landing_hide_title_and_subtitle,
            :landing_site_logo_follow_to_landing_page, :landing_navigation_link_color,
            :landing_site_logo_for_transparent_background, :landing_site_logo_for_white_background,
            :landing_desktop_header_image, :landing_mobile_header_image,
            :landing_desktop_header_video, :landing_mobile_header_video,
            landing_page_manager_ids: []
          )
        end
    end
  end
end
