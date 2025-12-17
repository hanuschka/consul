class Admin::ExternalApiKeysController < Admin::BaseController
  def index
    ensure_existence_of_api_keys_templates

    @external_api_keys = ExternalApiKey.all.order(:name)
  end

  def show
    @external_api_key = ExternalApiKey.find(params[:id])
  end

  def edit
    @external_api_key = ExternalApiKey.find(params[:id])
  end

  def update
    @external_api_key = ExternalApiKey.find(params[:id])
    @external_api_key.update!(external_api_key_params)
    redirect_to admin_external_api_keys_path, notice: t("admin.external_api_keys.flash.updated")
  end

  private

  def ensure_existence_of_api_keys_templates
    ExternalApiKey.ensure_existence_of_api_keys
  end

  def external_api_key_params
    params.require(:external_api_key).permit(:value)
  end
end
