module Adm
  class TagsController < Adm::BaseController
    def index
      authorize [:adm, :tag]
      @pagy, @tags = pagy(policy_scope([:adm, Tag]).order(:id))

      @breadcrumbs = [
        { name: t("adm.menu.items.home"), url: adm_root_path },
        { name: t("adm.menu.items.application") },
        { name: t("adm.menu.items.application_subitems.tags") }
      ]
    end

    def new
      @tag = Tag.new
      authorize [:adm, @tag]

      @breadcrumbs = [
        { name: t("adm.menu.items.home"), url: adm_root_path },
        { name: t("adm.menu.items.application") },
        { name: t("adm.menu.items.application_subitems.tags"), url: adm_tags_path },
        { name: t(".title") }
      ]
    end

    def create
      @tag = Tag.find_or_initialize_by(name: tag_params[:name])
      @tag.kind = "category"
      authorize [:adm, @tag]

      if @tag.save
        redirect_to adm_tags_path, notice: t(".success")
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @tag = Tag.category.find(params[:id])
      authorize [:adm, @tag]

      @breadcrumbs = [
        { name: t("adm.menu.items.home"), url: adm_root_path },
        { name: t("adm.menu.items.application") },
        { name: t("adm.menu.items.application_subitems.tags"), url: adm_tags_path },
        { name: t(".title") }
      ]
    end

    def update
      @tag = Tag.category.find(params[:id])
      authorize [:adm, @tag]

      if @tag.update(tag_params)
        redirect_to adm_tags_path, notice: t(".success")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @tag = Tag.category.find(params[:id])
      authorize [:adm, @tag]

      @tag.destroy!
      redirect_to adm_tags_path, notice: t(".success")
    end

    private

      def tag_params
        params.require(:tag).permit(:name)
      end
  end
end
