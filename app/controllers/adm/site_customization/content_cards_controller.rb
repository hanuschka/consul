module Adm
  module SiteCustomization
    class ContentCardsController < Adm::BaseController
      include Translatable

      def edit
        authorize [:adm, Setting], :update?
        @content_card = ::SiteCustomization::ContentCard.find(params[:id])
        @default_settings = ::SiteCustomization::ContentCard.default_settings[@content_card.kind] || {}

        @breadcrumbs = [
          { name: t("adm.menu.items.home"), url: adm_root_path },
          parent_breadcrumb,
          { name: @content_card.title }
        ]
      end

      def update
        authorize [:adm, Setting], :update?

        @content_card = ::SiteCustomization::ContentCard.find(params[:id])
        debugger
        @content_card.update(content_card_params) #rubocop:disable Rails/SaveBang

        respond_to do |format|
          format.html { redirect_to redirect_path, notice: t(".notice") }
        end
      end

      private

        def content_card_params
          params.require(:site_customization_content_card).permit(
           :active,
            translation_params(::SiteCustomization::ContentCard)
          ).merge(settings_params)
        end

        def landing_page
          @landing_page ||= @content_card.landing_page
        end

        def redirect_path
          landing_page.present? ? "#" : adm_homepage_path
        end

        def parent_breadcrumb
          if landing_page.present?
            { name: "lp", url: "#" }
          else
            { name: t("adm.menu.items.home"), url: adm_homepage_path }
          end
        end

        def settings_params
          return {} unless params[:site_customization_content_card][:settings].present?

          params.require(:site_customization_content_card).permit(
            settings: params[:site_customization_content_card][:settings].keys && permitted_setting_keys
          )
        end

        def permitted_setting_keys
          SiteCustomization::ContentCard.default_settings.map { |_k, v| v.keys }.flatten.map(&:to_s)
        end
    end
  end
end
