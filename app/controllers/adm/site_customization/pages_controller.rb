module Adm
  module SiteCustomization
    class PagesController < Adm::BaseController
      include Translatable

      def update
        authorize [:adm, ::SiteCustomization::Page]
        @page = ::SiteCustomization::Page.find(params[:id])
        @kind = params[:kind]&.to_sym

        if @page.update(page_params) #rubocop:disable Rails/SaveBang
          flash.now[:success] = t(".success")
        end
      end

      private

        def page_params
          params.require(:site_customization_page).permit(
            :slug, :status,
            translation_params(::SiteCustomization::Page)
          )
        end
    end
  end
end
