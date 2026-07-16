module Adm
  module SiteCustomization
    class PagesController < Adm::BaseController
      FOOTER_KEYS = ::SiteCustomization::Page::FOOTER_KEYS

      def index
        scope = policy_scope(::SiteCustomization::Page,
                             policy_scope_class: Adm::SiteCustomization::PagePolicy::Scope)

        ensure_default_pages

        @pages = scope.footer_pages
        @breadcrumbs = breadcrumbs
      end

      def edit
        @page = find_page
        authorize @page, :update?, policy_class: policy_class_for(@page)

        @breadcrumbs = breadcrumbs + [{ name: @page.title }]
      end

      def update
        @page = find_page
        authorize @page, :update?, policy_class: policy_class_for(@page)

        if @page.update(page_params)
          redirect_to adm_site_customization_pages_path, notice: t(".success")
        else
          @breadcrumbs = breadcrumbs + [{ name: @page.title }]
          render :edit, status: :unprocessable_entity
        end
      end

      def reorder
        authorize ::SiteCustomization::Page, :update?,
                  policy_class: Adm::SiteCustomization::PagePolicy

        ::SiteCustomization::Page.order_footer_pages(params[:tree].map { |item| item[:id] })
        head :ok
      end

      def toggle_status
        @page = find_page
        authorize @page, :update?, policy_class: policy_class_for(@page)

        @page.update(status: page_params[:status])

        respond_to do |format|
          format.turbo_stream
          format.html { redirect_to adm_site_customization_pages_path }
        end
      end

      private

        def find_page
          ::SiteCustomization::Page.footer_pages.find(params[:id])
        end

        # Safety net for environments where the release task
        # (pages:add_default_pages) hasn't run yet. Adopts an existing page
        # with the default slug instead of tripping the slug uniqueness
        # validation.
        def ensure_default_pages
          missing_keys = FOOTER_KEYS - ::SiteCustomization::Page.footer_pages.pluck(:footer_key)

          missing_keys.each do |key|
            existing_page = ::SiteCustomization::Page.where(projekt_id: nil).find_by(slug: key)

            if existing_page
              existing_page.update_columns(footer_key: key, footer_position: FOOTER_KEYS.index(key) + 1)
            else
              ::SiteCustomization::Page.create!(
                slug: key,
                footer_key: key,
                footer_position: FOOTER_KEYS.index(key) + 1,
                status: "draft",
                title: t("adm.site_customization.pages.default_titles.#{key}")
              )
            end
          end
        end

        def page_params
          params.require(:site_customization_page).permit(:title, :slug, :status, :content)
        end

        def breadcrumbs
          [
            { name: t("adm.menu.items.application"), icon: "desktop_windows" },
            { name: t("adm.menu.items.application_subitems.pages"), url: adm_site_customization_pages_path }
          ]
        end
    end
  end
end
