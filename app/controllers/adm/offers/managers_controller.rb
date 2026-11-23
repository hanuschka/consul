class Adm::Offers::ManagersController < Adm::Offers::BaseController
  include Admin::PendingRoleAssignable

  def index
    authorize OfferManager, policy_class: Adm::OfferManagerPolicy

    @pagy, @offer_managers = pagy(
      policy_scope(OfferManager, policy_scope_class: Adm::OfferManagerPolicy::Scope)
        .includes(:user)
        .order(id: :desc)
    )

    @breadcrumbs = [{ name: t("adm.offers.managers.index.title"), icon: "admin_panel_settings" }]
  end

  def new
    authorize OfferManager, :create?, policy_class: Adm::OfferManagerPolicy

    @breadcrumbs = [
      { name: t("adm.offers.managers.index.title"), url: adm_offers_managers_path, icon: "admin_panel_settings" },
      { name: t(".title") }
    ]
  end

  def destroy
    @offer_manager = OfferManager.find(params[:id])
    authorize @offer_manager, policy_class: Adm::OfferManagerPolicy

    @offer_manager.destroy!
  end

  def search
    authorize OfferManager, :create?, policy_class: Adm::OfferManagerPolicy

    params[:role] = "offer_manager"
    @users = User.search(params[:search]).where.missing(:offer_manager).limit(4)
    check_pending_for_search
  end

  private

    def pending_role_type
      "OfferManager"
    end
end
