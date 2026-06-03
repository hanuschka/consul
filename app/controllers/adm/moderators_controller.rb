module Adm
  class ModeratorsController < Adm::Moderation::BaseController
    include Admin::PendingRoleAssignable

    def index
      authorize [:adm, Moderator]
      @pagy, @moderators = pagy(policy_scope([:adm, Moderator]).order(id: :desc))

      @breadcrumbs = [
        { name: t("adm.moderators.index.breadcrumb"), icon: "badge" }
      ]
    end

    def new
      authorize [:adm, Moderator], :index?

      @breadcrumbs = [
        { name: t("adm.moderators.index.breadcrumb"), url: adm_moderators_path, icon: "badge" },
        { name: t(".title") }
      ]
    end

    def destroy
      authorize [:adm, Moderator], :index?
      @moderator = Moderator.find(params[:id])
      @moderator.destroy!
    end

    def search
      authorize [:adm, Moderator], :index?
      params[:role] = "moderator"
      @users = User.search(params[:search]).where.missing(:moderator).limit(4)
      check_pending_for_search
    end
  end
end
