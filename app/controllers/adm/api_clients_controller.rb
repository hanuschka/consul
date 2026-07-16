class Adm::ApiClientsController < Adm::BaseController
  SERVICE_USER_PERMITTED_ATTRIBUTES = [
    :username, :first_name, :last_name, :background_image,
    { image_attributes: [:id, :attachment, :cached_attachment, :user_id, :_destroy] }
  ].freeze

  def index
    @pagy, @api_clients = pagy(
      policy_scope(ApiClient, policy_scope_class: Adm::ApiClientPolicy::Scope)
        .includes(user: :image)
        .order(created_at: :desc)
    )

    @breadcrumbs = [
      { name: t("adm.api_clients.index.title"), icon: "api" }
    ]
  end

  def show
    @api_client = ApiClient.find(params[:id])
    authorize [:adm, @api_client], policy_class: Adm::ApiClientPolicy

    @breadcrumbs = breadcrumbs_with(@api_client.name)
  end

  def logs
    @api_client = ApiClient.find(params[:id])
    authorize [:adm, @api_client], policy_class: Adm::ApiClientPolicy

    scope = policy_scope(ApiRequestLog, policy_scope_class: Adm::ApiRequestLogPolicy::Scope)
      .where(api_client_id: @api_client.id)
    filtered = Adm::ApiRequestLogsQuery.call(scope.includes(:api_client), params)

    @pagy, @api_request_logs = pagy(filtered.order(created_at: :desc), items: 50)

    @logs_present = scope.exists?
    assign_log_filter_options(@api_client)

    @breadcrumbs = logs_breadcrumbs(@api_client)
  end

  def new
    @api_client = ApiClient.new
    authorize [:adm, @api_client], policy_class: Adm::ApiClientPolicy

    @breadcrumbs = breadcrumbs_with(t("adm.api_clients.new.title"))
  end

  def create
    @api_client = ApiClient.new(api_client_params)
    authorize [:adm, @api_client], policy_class: Adm::ApiClientPolicy

    if save_with_service_user

      redirect_to adm_api_client_path(@api_client), notice: t("adm.api_clients.flash.created")
    else
      @breadcrumbs = breadcrumbs_with(t("adm.api_clients.new.title"))

      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @api_client = ApiClient.find(params[:id])
    authorize [:adm, @api_client], policy_class: Adm::ApiClientPolicy

    @breadcrumbs = breadcrumbs_with(t("adm.api_clients.edit.title"))
  end

  def update
    @api_client = ApiClient.find(params[:id])
    authorize [:adm, @api_client], policy_class: Adm::ApiClientPolicy
    @api_client.assign_attributes(api_client_params)

    if save_with_service_user

      redirect_to adm_api_client_path(@api_client), notice: t("adm.api_clients.flash.updated")
    else
      @breadcrumbs = breadcrumbs_with(t("adm.api_clients.edit.title"))

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

    def save_with_service_user
      ActiveRecord::Base.transaction do
        @api_client.save!

        if @api_client.dedicated_user_mode?
          save_service_user
        end
      end

      true
    rescue ActiveRecord::RecordInvalid
      false
    end

    def save_service_user
      if @api_client.user.present?
        @api_client.user.update!(service_user_attributes)
      else
        ::ApiClients::CreateServiceUserService.call(
          api_client: @api_client,
          user_attributes: service_user_attributes
        )
      end
    end

    def breadcrumbs_with(name)
      [
        { name: t("adm.api_clients.index.title"), icon: "api", url: adm_api_clients_path },
        { name: name }
      ]
    end

    def logs_breadcrumbs(api_client)
      [
        { name: t("adm.api_clients.index.title"), icon: "api", url: adm_api_clients_path },
        { name: api_client.name, url: adm_api_client_path(api_client) },
        { name: t("adm.api_clients.logs.title") }
      ]
    end

    def assign_log_filter_options(api_client)
      @http_method_options = ApiRequestLog::HTTP_METHOD_BADGE_VARIANTS.keys
      @response_status_options = ApiRequestLog
        .where(api_client_id: api_client.id)
        .where.not(response_status: nil)
        .distinct
        .order(:response_status)
        .pluck(:response_status)
    end

    def api_client_params
      params.require(:api_client).permit(:name, :domain, :access_level, :service_user_email, :use_system_user)
    end

    def service_user_attributes
      user_params = params.require(:api_client)[:user]
      return {} if user_params.blank?

      user_params.permit(*SERVICE_USER_PERMITTED_ATTRIBUTES)
    end
end
