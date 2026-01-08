module Adm
  class IdeaManagersController < Adm::BaseController
    def index
      authorize [:adm, IdeaManager]
      @pagy, @idea_managers = pagy(policy_scope([:adm, IdeaManager]).order(id: :desc))

      @breadcrumbs = [
        { name: t("adm.menu.items.home"), url: adm_root_path },
        { name: t("adm.menu.items.profiles") },
        { name: t("adm.menu.items.profiles_subitems.idea_managers") }
      ]
    end

    def new
      authorize [:adm, IdeaManager], :index?

      @breadcrumbs = [
        { name: t("adm.menu.items.home"), url: adm_root_path },
        { name: t("adm.menu.items.profiles") },
        { name: t("adm.menu.items.profiles_subitems.idea_managers"), url: adm_idea_managers_path },
        { name: t(".title") }
      ]
    end

    def destroy
      authorize [:adm, IdeaManager], :index?
      @idea_manager = IdeaManager.find(params[:id])
      @idea_manager.destroy!
    end

    def search
      authorize [:adm, IdeaManager], :index?
      params[:role] = "idea_manager"
      @users = User.search(params[:search]).where.missing(:idea_manager).limit(4)
    end
  end
end
