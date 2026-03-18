module Adm
  module SiteCustomization
    class PagesController < Adm::BaseController
      SLUGS = %w[privacy conditions impressum].freeze

      def edit
        @page = find_or_create_page(params[:slug])
        authorize @page, :update?, policy_class: policy_class_for(@page)

        @breadcrumbs = [
          { name: t("adm.menu.items.pages"), icon: "description" },
          { name: @page.title }
        ]
      end

      private

        def find_or_create_page(slug)
          raise ActionController::RoutingError, "Not Found" unless slug.in?(SLUGS)

          ::SiteCustomization::Page.find_or_create_by!(slug: slug) do |page|
            page.status = "published"
            page.title = t("adm.site_customization.pages.default_titles.#{slug}")
          end
        end
    end
  end
end
