module Adm
  class WhatsappController < Adm::BaseController
    FEATURE_SETTING_KEYS = %w[
      feature.whatsapp_bot
    ].freeze

    TEXT_SETTING_KEYS = %w[
      whatsapp.broadcast_template
      whatsapp.broadcast_template_language
      whatsapp.transcription_model
      whatsapp.message_retention_days
      whatsapp.max_voice_megabytes
    ].freeze

    before_action :authorize_settings
    before_action :load_configured_state

    def show
      @breadcrumbs = [
        { name: t("adm.menu.items.application"), icon: "desktop_windows" },
        { name: t("adm.whatsapp.show.title") }
      ]

      return if !@configured

      load_settings
      load_audience
      load_integration_state
    end

    def test_message
      return head :forbidden if !@configured

      result =
        ::Whatsapp::SendTestMessageService.call(
          phone: params.dig(:test, :phone),
          body: t("adm.whatsapp.test_message.body")
        )

      render json: result
    end

    def create_template
      template_params = params.require(:template).permit(:name, :language, :body)
      response =
        ::Whatsapp::CreateBroadcastTemplateService.call(
          name: template_params[:name],
          language: template_params[:language],
          body: template_params[:body]
        )

      if response&.success?
        flash[:success] = t("adm.whatsapp.template.submitted")
      else
        flash[:error] = t("adm.whatsapp.template.failed", error: error_message(response))
      end

      redirect_to adm_whatsapp_path
    end

    def use_template
      Setting["whatsapp.broadcast_template"] = params[:name].to_s
      Setting["whatsapp.broadcast_template_language"] = params[:language].to_s

      flash[:success] = t("adm.whatsapp.template.selected", name: params[:name])

      redirect_to adm_whatsapp_path
    end

    private

      def authorize_settings
        authorize [:adm, Setting], :update?
      end

      def load_configured_state
        @configured = ::Whatsapp.configured?
      end

      def load_settings
        settings_by_key =
          Setting.where(key: FEATURE_SETTING_KEYS + TEXT_SETTING_KEYS).index_by(&:key)

        @feature_settings = FEATURE_SETTING_KEYS.filter_map { |key| settings_by_key[key] }
        @text_settings = TEXT_SETTING_KEYS.filter_map { |key| settings_by_key[key] }
      end

      def load_audience
        @subscribed_count = WhatsappAccount.subscribed.count
        @linked_count = WhatsappAccount.verified.count
        @eligible_projekt_phases = WhatsappEligiblePhasesQuery.call
      end

      def load_integration_state
        @webhook_status = ::Whatsapp::WebhookStatusService.call(expected_base_url: request.base_url)
        @templates = ::Whatsapp::BroadcastTemplatesService.call
      end

      def error_message(response)
        return t("adm.whatsapp.not_configured") if response.blank?

        response.error_payload.to_s.truncate(200)
      end
  end
end
