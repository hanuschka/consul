class Adm::Moderation::UsersController < Adm::Moderation::BaseController
  def index
    authorize [:adm, :moderation, User]
    base_scope = policy_scope([:adm, :moderation, User])
    base_scope = base_scope.search(params[:search]) if params[:search].present?

    @pagy, @users = pagy(base_scope)

    @breadcrumbs = [
      { name: I18n.t("adm.moderation.menu.title"), icon: "block" },
      { name: I18n.t("adm.moderation.menu.items.users") }
    ]
  end

  def hide
    @user = User.find(params[:id])
    authorize [:adm, :moderation, @user], :hide?

    @user.hide
    Activity.log(current_user, :hide, @user)
    @user.reload
  end

  def block
    @user = User.find(params[:id])
    authorize [:adm, :moderation, @user], :block?

    @user.block
    Activity.log(current_user, :block, @user)
    @user.reload
  end
end
