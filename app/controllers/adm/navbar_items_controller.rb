module Adm
  class NavbarItemsController < Adm::BaseController
    def new
      @navbar_item = NavbarItem.new
      authorize [:adm, @navbar_item]

      @breadcrumbs = [
        { name: t("adm.menu.items.home"), url: adm_root_path },
        { name: t("adm.menu.items.application") },
        { name: t("adm.menu.items.application_subitems.navbar"), url: adm_navbar_path },
        { name: t(".title") }
      ]
    end

    def create
      @navbar_item = NavbarItem.new(navbar_item_params)
      authorize [:adm, @navbar_item]

      if @navbar_item.save
        redirect_to adm_navbar_path
      else
        render :new
      end
    end

    def destroy
      @navbar_item = NavbarItem.find(params[:id])
      authorize [:adm, @navbar_item]

      @navbar_item.destroy!

      redirect_to adm_documents_path,
        notice: t("admin.documents.destroy.success_notice")
    end

    private

      def navbar_item_params
        params.require(:navbar_item).permit(
          :kind, :preset, :projekt_id, :external_title, :external_url
        )
      end
  end
end
