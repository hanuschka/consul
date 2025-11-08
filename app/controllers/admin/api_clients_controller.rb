class Admin::ApiClientsController < Admin::BaseController
  load_and_authorize_resource class: "ApiClient"

  def index
    @api_clients = @api_clients.order(created_at: :desc).page(params[:page])
  end

  def show
  end

  def new
  end

  def create
    @api_client = ApiClient.new(api_client_params)
    @api_client.registration_status = :registered

    if @api_client.save
      redirect_to admin_api_client_path(@api_client), notice: t("admin.api_clients.form.created")
    else
      render :new
    end
  end

  def edit
  end

  def update
    if @api_client.update(api_client_params)
      redirect_to admin_api_client_path(@api_client), notice: t("admin.api_clients.form.updated")
    else
      render :edit
    end
  end

  def destroy
    @api_client.destroy
    redirect_to admin_api_clients_path, notice: t("admin.api_clients.form.deleted")
  end

  private

  def api_client_params
    params.require(:api_client).permit(:name, :domain, :access_level, :service_user_email)
  end
end
