module Adm
  class WhatsappController < Adm::BaseController
    before_action :ensure_feature_enabled!
    before_action :authorize_settings

    def show
      @subscribed_count = WhatsappAccount.subscribed.count
      @linked_count = WhatsappAccount.verified.count
      @eligible_projekt_phases = WhatsappEligiblePhasesQuery.call
      @webhook_status = ::Whatsapp::WebhookStatusService.call(expected_base_url: request.base_url)
      @templates = ::Whatsapp::BroadcastTemplatesService.call

      @breadcrumbs = [
        { name: t("adm.menu.items.application"), icon: "desktop_windows" },
        { name: t(".title") }
      ]
    end

    def test_message
      phone = params.dig(:test, :phone)
      response =
        ::Whatsapp::SendTestMessageService.call(
          phone: phone,
          body: t("adm.whatsapp.test_message.body")
        )

      if response&.success?
        flash[:success] = t("adm.whatsapp.test_message.sent", phone: phone)
      else
        flash[:error] = t("adm.whatsapp.test_message.failed", error: error_message(response))
      end

      redirect_to adm_whatsapp_path
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

      def ensure_feature_enabled!
        return if ::Whatsapp.enabled?

        redirect_to adm_root_path
      end

      def error_message(response)
        return t("adm.whatsapp.not_configured") if response.blank?

        response.error_payload.to_s.truncate(200)
      end
  end
end
