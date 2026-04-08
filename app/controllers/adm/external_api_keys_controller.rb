class Adm::ExternalApiKeysController < Adm::BaseController
  def index
    ExternalApiKey.ensure_existence_of_api_keys
    authorize [:adm, ExternalApiKey], :index?, policy_class: Adm::ExternalApiKeyPolicy
    @external_api_keys = policy_scope(ExternalApiKey, policy_scope_class: Adm::ExternalApiKeyPolicy::Scope).order(:name)

    @breadcrumbs = [
      { name: t("adm.external_api_keys.index.title"), icon: "key" }
    ]
  end

  def show
    @external_api_key = ExternalApiKey.find(params[:id])
    authorize [:adm, @external_api_key], policy_class: Adm::ExternalApiKeyPolicy

    @breadcrumbs = [
      { name: t("adm.external_api_keys.index.title"), icon: "key", url: adm_external_api_keys_path },
      { name: @external_api_key.service.titleize }
    ]
  end

  def edit
    @external_api_key = ExternalApiKey.find(params[:id])
    authorize [:adm, @external_api_key], policy_class: Adm::ExternalApiKeyPolicy

    @breadcrumbs = [
      { name: t("adm.external_api_keys.index.title"), icon: "key", url: adm_external_api_keys_path },
      { name: t("adm.external_api_keys.edit.title") }
    ]
  end

  def update
    @external_api_key = ExternalApiKey.find(params[:id])
    authorize [:adm, @external_api_key], policy_class: Adm::ExternalApiKeyPolicy
    @external_api_key.update!(external_api_key_params)

    redirect_to adm_external_api_keys_path, notice: t("adm.external_api_keys.flash.updated")
  end

  private

    def external_api_key_params
      params.require(:external_api_key).permit(:value)
    end
end
