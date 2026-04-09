module Adm
  module SiteCustomization
    class ContentCardsController < Adm::BaseController
      include Translatable

      def edit
        authorize [:adm, Setting], :update?
        @content_card = ::SiteCustomization::ContentCard.find(params[:id])
        @content_card_settings = ::SiteCustomization::ContentCard::DEFAULT_SETTINGS[@content_card.kind]

        @breadcrumbs = parent_breadcrumbs + [{ name: @content_card.title }]
      end

      def update
        authorize [:adm, Setting], :update?

        @content_card = ::SiteCustomization::ContentCard.find(params[:id])
        @content_card.update(content_card_params) #rubocop:disable Rails/SaveBang

        redirect_to redirect_path, notice: t(".notice")
      end

      def toggle_active
        authorize [:adm, Setting], :update?

        @content_card = ::SiteCustomization::ContentCard.find(params[:id])
        @content_card.update(active: !@content_card.active) #rubocop:disable Rails/SaveBang
      end

      def reorder
        authorize [:adm, Setting], :update?

        ::SiteCustomization::ContentCard.order_content_cards(params[:ordered_list])
        head :ok
      end

      private

        def content_card_params
          params.require(:site_customization_content_card).permit(
           :active, :title,
           *::SiteCustomization::ContentCard::DEFAULT_SETTINGS.map { |_k, v| v.keys }.flatten.uniq,
           translation_params(::SiteCustomization::ContentCard)
          )
        end

        def landing_page
          @landing_page ||= @content_card.landing_page
        end

        def adm_menu_component
          @content_card&.landing_page.present? ? Adm::LandingPages::MenuComponent.new : super
        end

        def redirect_path
          if landing_page.present?
            edit_adm_landing_pages_landing_page_path(landing_page)
          else
            adm_homepage_path(anchor: "content-cards-table")
          end
        end

        def parent_breadcrumbs
          if landing_page.present?
            [
              { name: t("adm.landing_pages.title"), icon: "web", url: adm_landing_pages_root_path },
              { name: landing_page.title, url: edit_adm_landing_pages_landing_page_path(landing_page) }
            ]
          else
            [
              { name: t("adm.menu.items.application"), icon: "desktop_windows" },
              { name: t("adm.menu.items.application_subitems.homepage"), url: adm_homepage_path }
            ]
          end
        end
    end
  end
end
