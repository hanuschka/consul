class Adm::ApiClients::ServiceUsersController < Adm::BaseController
  SERVICE_USER_PERMITTED_ATTRIBUTES = [
    :username, :first_name, :last_name, :background_image,
    { image_attributes: [:id, :attachment, :cached_attachment, :ai_generated, :user_id, :_destroy] }
  ].freeze

  before_action :load_api_client

  def edit
    @breadcrumbs = breadcrumbs
  end

  def update
    if @user.update(service_user_params)

      redirect_to edit_adm_api_client_service_user_path(@api_client),
        notice: t("adm.api_clients.service_users.flash.updated")
    else
      @breadcrumbs = breadcrumbs

      render :edit, status: :unprocessable_entity
    end
  end

  private

    def load_api_client
      @api_client = ApiClient.find(params[:api_client_id])
      authorize [:adm, @api_client], policy_class: Adm::ApiClientPolicy

      @user = @api_client.user

      if @user.blank?

        redirect_to edit_adm_api_client_path(@api_client),
          alert: t("adm.api_clients.service_users.flash.no_service_user")
      end
    end

    def service_user_params
      params.require(:user).permit(*SERVICE_USER_PERMITTED_ATTRIBUTES)
    end

    def breadcrumbs
      [
        { name: t("adm.api_clients.index.title"), icon: "api", url: adm_api_clients_path },
        { name: @api_client.name, url: edit_adm_api_client_path(@api_client) },
        { name: t("adm.api_clients.service_users.edit.title") }
      ]
    end
end
