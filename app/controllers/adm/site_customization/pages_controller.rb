module Adm
  module SiteCustomization
    class PagesController < Adm::BaseController
      SLUGS = %w[privacy conditions impressum contact_us].freeze

      def edit
        @page = find_or_create_page(params[:slug])
        authorize @page, :update?, policy_class: policy_class_for(@page)

        @breadcrumbs = breadcrumbs
      end

      def update
        @page = find_or_create_page(params[:slug])
        authorize @page, :update?, policy_class: policy_class_for(@page)

        if @page.update(page_params)
          redirect_to adm_site_customization_edit_page_by_slug_path(slug: @page.slug),
            notice: t(".success")
        else
          @breadcrumbs = breadcrumbs
          render :edit, status: :unprocessable_entity
        end
      end

      private

        def find_or_create_page(slug)
          raise ActionController::RoutingError, "Not Found" unless slug.in?(SLUGS)

          ::SiteCustomization::Page.find_or_create_by!(slug: slug) do |page|
            page.status = "published"
            page.title = t("adm.site_customization.pages.default_titles.#{slug}")
          end
        end

        def page_params
          params.require(:site_customization_page).permit(:status, :content)
        end

        def breadcrumbs
          [
            { name: t("adm.menu.items.application"), icon: "desktop_windows" },
            { name: t("adm.menu.items.application_subitems.pages") }
          ]
        end
    end
  end
end
