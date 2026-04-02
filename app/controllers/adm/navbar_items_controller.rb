module Adm
  class NavbarItemsController < Adm::BaseController
    def new
      @navbar_item = NavbarItem.new(landing_page_id: params[:landing_page_id])
      authorize [:adm, @navbar_item]

      @landing_page = find_landing_page
      set_form_variables

      @breadcrumbs = navbar_item_breadcrumbs(t(".title"))
    end

    def create
      @navbar_item = NavbarItem.new(navbar_item_params)
      authorize [:adm, @navbar_item]

      @landing_page = find_landing_page

      if @navbar_item.save
        redirect_to after_save_redirect_path
      else
        set_form_variables
        render :new
      end
    end

    def destroy
      @navbar_item = NavbarItem.find(params[:id])
      authorize [:adm, @navbar_item]

      @landing_page = @navbar_item.landing_page

      @navbar_item.destroy!

      redirect_to after_save_redirect_path,
        notice: t(".success_notice")
    end

    def reorder
      authorize [:adm, NavbarItem], :create?

      ActiveRecord::Base.transaction do
        reorder_items(params[:tree])
      end

      head :ok
    end

    private

      def navbar_item_params
        params.require(:navbar_item).permit(
          :kind, :preset, :projekt_id, :external_title, :external_url,
          :landing_page_id
        )
      end

      def find_landing_page
        landing_page_id = params[:landing_page_id] || params.dig(:navbar_item, :landing_page_id)
        return if landing_page_id.blank?

        ::SiteCustomization::Page.find(landing_page_id)
      end

      def set_form_variables
        @available_kinds = NavbarItem.kinds.keys

        @available_presets =
          if @landing_page.present?
            NavbarItem::PRESETS.select { |k, _| k.in?(NavbarItem::LANDING_PAGE_ALLOWED_PRESETS) }
          else
            NavbarItem::PRESETS
          end

        @available_projekts =
          if @landing_page.present?
            @landing_page.landing_projekts
          else
            Projekt.all
          end

        @form_url =
          if @landing_page.present?
            adm_landing_pages_landing_page_navbar_items_path(@landing_page)
          else
            adm_navbar_items_path
          end
      end

      def after_save_redirect_path
        if @landing_page.present?
          edit_adm_landing_pages_landing_page_path(@landing_page, anchor: "navbar")
        else
          adm_navbar_path
        end
      end

      def navbar_item_breadcrumbs(last_crumb)
        if @landing_page.present?
          [
            { name: t("adm.landing_pages.title"), icon: "web" },
            {
              name: @landing_page.title,
              url: edit_adm_landing_pages_landing_page_path(@landing_page)
            },
            { name: last_crumb }
          ]
        else
          [
            { name: t("adm.menu.items.application"), icon: "desktop_windows" },
            { name: t("adm.menu.items.application_subitems.navbar"), url: adm_navbar_path },
            { name: last_crumb }
          ]
        end
      end

      def reorder_items(nodes, parent_id = nil)
        nodes.each_with_index do |node, index|
          item = NavbarItem.find(node[:id])

          item.update!(
            parent_id: parent_id,
            position: index + 1
          )

          reorder_items(node[:children], item.id) if node[:children].present?
        end
      end
  end
end
