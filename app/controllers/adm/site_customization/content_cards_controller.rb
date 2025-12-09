module Adm
  module SiteCustomization
    class ContentCardsController < Adm::BaseController
      include Translatable

      def edit
        authorize [:adm, Setting], :update?
        @content_card = ::SiteCustomization::ContentCard.find(params[:id])
        @content_card_settings = ::SiteCustomization::ContentCard::DEFAULT_SETTINGS[@content_card.kind]

        @breadcrumbs = [
          { name: t("adm.menu.items.home"), url: adm_root_path },
          parent_breadcrumb,
          { name: @content_card.title }
        ]
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

      def order_content_cards
        authorize [:adm, Setting], :update?

        ::SiteCustomization::ContentCard.order_content_cards(params[:ordered_list])
        head :ok
      end

      private

        def content_card_params
          params.require(:site_customization_content_card).permit(
           :active,
           *::SiteCustomization::ContentCard::DEFAULT_SETTINGS.map { |_k, v| v.keys }.flatten.uniq,
           translation_params(::SiteCustomization::ContentCard)
          )
        end

        def landing_page
          @landing_page ||= @content_card.landing_page
        end

        def redirect_path
          landing_page.present? ? "#" : adm_homepage_path(anchor: "content-cards-table")
        end

        def parent_breadcrumb
          if landing_page.present?
            { name: "lp", url: "#" }
          else
            { name: t("adm.menu.items.home"), url: adm_homepage_path }
          end
        end
    end
  end
end
