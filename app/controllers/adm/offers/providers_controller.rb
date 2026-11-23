class Adm::Offers::ProvidersController < Adm::Offers::BaseController
  before_action :set_provider, only: [:edit, :update, :destroy]

  def index
    authorize Offer::Provider, :index?, policy_class: Adm::Offers::ProviderPolicy

    @name_header_options = { sort: true, search: true }

    @pagy, @providers = pagy(
      Adm::OfferProvidersQuery.new(
        policy_scope(Offer::Provider, policy_scope_class: Adm::Offers::ProviderPolicy::Scope)
          .includes(:users, :offers),
        params
      ).call
    )

    @breadcrumbs = [{ name: t("adm.offers.providers.index.title"), icon: "badge" }]
  end

  def new
    @provider = Offer::Provider.new
    authorize @provider, policy_class: Adm::Offers::ProviderPolicy
    prepare_form(t(".title"))
  end

  def create
    @provider = Offer::Provider.new(provider_params)
    authorize @provider, policy_class: Adm::Offers::ProviderPolicy

    if @provider.save
      redirect_to adm_offers_providers_path, notice: t(".success")
    else
      prepare_form(t("adm.offers.providers.new.title"))
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    prepare_form(@provider.name)
  end

  def update
    if @provider.update(provider_params)
      redirect_to adm_offers_providers_path, notice: t(".success")
    else
      prepare_form(@provider.name_was)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @provider.destroy
      redirect_to adm_offers_providers_path, notice: t(".success")
    else
      redirect_to adm_offers_providers_path, alert: t(".cannot_destroy")
    end
  end

  private

    def set_provider
      @provider = Offer::Provider.find(params[:id])
      authorize @provider, policy_class: Adm::Offers::ProviderPolicy
    end

    def prepare_form(title)
      @breadcrumbs = [
        { name: t("adm.offers.providers.index.title"), url: adm_offers_providers_path, icon: "badge" },
        { name: title }
      ]
    end

    def provider_params
      params.require(:offer_provider).permit(:name, :email_list)
    end
end
