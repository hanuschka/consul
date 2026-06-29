class Adm::ExternalApiKeysController < Adm::BaseController
  def index
    ExternalApiKey.ensure_existence_of_api_keys
    authorize [:adm, ExternalApiKey], :index?, policy_class: Adm::ExternalApiKeyPolicy
    @external_api_keys = policy_scope(ExternalApiKey, policy_scope_class: Adm::ExternalApiKeyPolicy::Scope).order(:name)

    if !Ai::Settings.feature_enabled?
      @external_api_keys = @external_api_keys.where.not(service: "openai")
    end

    @breadcrumbs = [
      { name: t("adm.external_api_keys.index.title"), icon: "key" }
    ]
  end

  def show
    @external_api_key = ExternalApiKey.find(params[:id])
    authorize [:adm, @external_api_key], policy_class: Adm::ExternalApiKeyPolicy

    service_name = t("admin.external_api_keys.services.#{@external_api_key.service}", default: @external_api_key.service)
    @breadcrumbs = [
      { name: t("adm.external_api_keys.index.title"), icon: "key", url: adm_external_api_keys_path },
      { name: service_name },
      { name: "API Key" }
    ]
  end

  def edit
    @external_api_key = ExternalApiKey.find(params[:id])
    authorize [:adm, @external_api_key], policy_class: Adm::ExternalApiKeyPolicy

    service_name = t("admin.external_api_keys.services.#{@external_api_key.service}", default: @external_api_key.service)
    @breadcrumbs = [
      { name: t("adm.external_api_keys.index.title"), icon: "key", url: adm_external_api_keys_path },
      { name: service_name, url: adm_external_api_key_path(@external_api_key) },
      { name: @external_api_key.value.present? ? t("adm.external_api_keys.edit.title") : t("adm.external_api_keys.show.add_key") }
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
