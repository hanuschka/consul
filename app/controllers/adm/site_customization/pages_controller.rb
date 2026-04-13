module Adm
  module SiteCustomization
    class PagesController < Adm::BaseController
      SLUGS = %w[privacy conditions impressum contact_us].freeze

      def edit
        @page = find_or_create_page(params[:slug])
        authorize @page, :update?, policy_class: policy_class_for(@page)

        @breadcrumbs = [
          { name: t("adm.menu.items.application"), icon: "desktop_windows" },
          { name: t("adm.menu.items.application_subitems.pages") }
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
