class Adm::ApiClientsController < Adm::BaseController
  def index
    @pagy, @api_clients = pagy(
      policy_scope(ApiClient, policy_scope_class: Adm::ApiClientPolicy::Scope).order(created_at: :desc)
    )

    @breadcrumbs = [
      { name: t("adm.api_clients.index.title"), icon: "api" }
    ]
  end

  def show
    @api_client = ApiClient.find(params[:id])
    authorize [:adm, @api_client], policy_class: Adm::ApiClientPolicy

    @breadcrumbs = [
      { name: t("adm.api_clients.index.title"), icon: "api", url: adm_api_clients_path },
      { name: @api_client.name }
    ]
  end

  def new
    @api_client = ApiClient.new
    authorize [:adm, @api_client], policy_class: Adm::ApiClientPolicy

    @breadcrumbs = [
      { name: t("adm.api_clients.index.title"), icon: "api", url: adm_api_clients_path },
      { name: t("adm.api_clients.new.title") }
    ]
  end

  def create
    @api_client = ApiClient.new(api_client_params)
    authorize [:adm, @api_client], policy_class: Adm::ApiClientPolicy

    if @api_client.save
      redirect_to adm_api_client_path(@api_client), notice: t("adm.api_clients.flash.created")
    else
      @breadcrumbs = [
        { name: t("adm.api_clients.index.title"), icon: "api", url: adm_api_clients_path },
        { name: t("adm.api_clients.new.title") }
      ]

      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @api_client = ApiClient.find(params[:id])
    authorize [:adm, @api_client], policy_class: Adm::ApiClientPolicy

    @breadcrumbs = [
      { name: t("adm.api_clients.index.title"), icon: "api", url: adm_api_clients_path },
      { name: t("adm.api_clients.edit.title") }
    ]
  end

  def update
    @api_client = ApiClient.find(params[:id])
    authorize [:adm, @api_client], policy_class: Adm::ApiClientPolicy

    if @api_client.update(api_client_params)
      redirect_to adm_api_client_path(@api_client), notice: t("adm.api_clients.flash.updated")
    else
      @breadcrumbs = [
        { name: t("adm.api_clients.index.title"), icon: "api", url: adm_api_clients_path },
        { name: t("adm.api_clients.edit.title") }
      ]

      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @api_client = ApiClient.find(params[:id])
    authorize [:adm, @api_client], policy_class: Adm::ApiClientPolicy
    @api_client.destroy!

    redirect_to adm_api_clients_path, notice: t("adm.api_clients.flash.deleted")
  end

  def regenerate_token
    @api_client = ApiClient.find(params[:id])
    authorize [:adm, @api_client], policy_class: Adm::ApiClientPolicy
    @api_client.regenerate_access_token

    redirect_to adm_api_client_path(@api_client), notice: t("adm.api_clients.flash.token_regenerated")
  end

  private

    def api_client_params
      params.require(:api_client).permit(:name, :domain, :access_level, :service_user_email)
    end
end
