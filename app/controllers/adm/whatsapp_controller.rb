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

    DIALOGS_PER_PAGE = 20

    # PDF QR poster disabled for now. Restoring it means uncommenting, in this
    # file: the constant below, the `except: :qr_poster` filter, the qr_poster
    # action and the four private helpers at the bottom — plus the route in
    # config/routes/adm.rb and the download button in
    # Adm::WhatsappQrCodeComponent.
    # QR_POSTER_MODULE_SIZE = 14

    before_action :authorize_settings # , except: :qr_poster
    before_action :load_configured_state

    def show
      @breadcrumbs = [
        { name: t("adm.menu.items.application"), icon: "desktop_windows" },
        { name: t("adm.whatsapp.show.title") }
      ]

      return if !@configured

      load_settings
      load_eligible_phases
      load_integration_state
      load_reach_stats
      load_dialogs
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

    # def qr_poster
    #   token = params[:token].presence
    #   subject = token.present? ? ::Whatsapp::QrTokenSubjectService.call(token: token) : nil
    #
    #   if token.present? && subject.blank?
    #     raise ActiveRecord::RecordNotFound
    #   end
    #
    #   authorize_qr_poster(subject)
    #
    #   send_data qr_poster_pdf(token, subject),
    #     filename: "#{["whatsapp-qr", token].compact.join("-").parameterize}.pdf",
    #     type: "application/pdf",
    #     disposition: "attachment"
    # end

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

      # def authorize_qr_poster(subject)
      #   projekt = subject.is_a?(ProjektPhase) ? subject.projekt : subject
      #
      #   return authorize [:adm, :projekts, projekt], :show? if projekt.present?
      #
      #   authorize_settings
      # end
      #
      # def qr_poster_pdf(token, subject)
      #   deep_link = ::Whatsapp.deep_link_url_for(token)
      #   html = render_to_string(
      #     template: "adm/whatsapp/qr_poster",
      #     layout: "pdf_whatsapp_qr",
      #     formats: [:html],
      #     locals: {
      #       headline: qr_poster_headline(subject),
      #       preline: subject.is_a?(ProjektPhase) ? projekt_title(subject.projekt) : nil,
      #       deep_link: deep_link,
      #       qr_svg: ::Whatsapp.qr_svg(deep_link, module_size: QR_POSTER_MODULE_SIZE)
      #     }
      #   )
      #
      #   Grover.new(html, display_url: request.base_url).to_pdf
      # end
      #
      # def qr_poster_headline(subject)
      #   return subject.title if subject.is_a?(ProjektPhase)
      #   return projekt_title(subject) if subject.is_a?(Projekt)
      #
      #   Setting["org_name"].presence || t("adm.whatsapp.show.title")
      # end
      #
      # def projekt_title(projekt)
      #   projekt.page&.title.presence || projekt.name
      # end

      def load_configured_state
        @configured = ::Whatsapp.configured?
      end

      def load_settings
        settings_by_key =
          Setting.where(key: FEATURE_SETTING_KEYS + TEXT_SETTING_KEYS).index_by(&:key)

        @feature_settings = FEATURE_SETTING_KEYS.filter_map { |key| settings_by_key[key] }
        @text_settings = TEXT_SETTING_KEYS.filter_map { |key| settings_by_key[key] }
      end

      def load_eligible_phases
        @eligible_projekt_phases = WhatsappEligiblePhasesQuery.call
      end

      def load_integration_state
        @webhook_status = ::Whatsapp::WebhookStatusService.call(expected_base_url: request.base_url)
        @templates = ::Whatsapp::BroadcastTemplatesService.call
      end

      def load_reach_stats
        @reach_stats = ::Whatsapp::ReachStatsService.call
      end

      def load_dialogs
        @dialogs_present = WhatsappAccount.exists?
        scope = WhatsappAccount.includes(:user, :whatsapp_conversation)

        @pagy, @dialogs = pagy(
          WhatsappDialogsQuery.call(scope, params),
          limit: DIALOGS_PER_PAGE
        )

        @dialog_message_counts = dialog_message_counts
        @dialog_last_messages = dialog_last_messages

        assign_dialog_filter_options
      end

      def assign_dialog_filter_options
        @dialog_state_options = WhatsappAccount.states.keys.map do |state|
          [t("adm.whatsapp.dialogs.states.#{state}"), state]
        end

        @dialog_step_options = WhatsappConversation.steps.keys.excluding("idle").map do |step|
          [t("adm.whatsapp.steps.#{step}"), step]
        end

        @dialog_activity_options = WhatsappDialogsQuery::ACTIVITY_OPTIONS.map do |option|
          [t("adm.whatsapp.dialogs.activity_options.#{option}"), option]
        end
      end

      def dialog_message_counts
        WhatsappMessage
          .where(whatsapp_account_id: @dialogs.map(&:id))
          .group(:whatsapp_account_id)
          .count
      end

      def dialog_last_messages
        WhatsappMessage
          .where(whatsapp_account_id: @dialogs.map(&:id))
          .select("DISTINCT ON (whatsapp_account_id) whatsapp_messages.*")
          .order(:whatsapp_account_id, created_at: :desc)
          .index_by(&:whatsapp_account_id)
      end

      def error_message(response)
        return t("adm.whatsapp.not_configured") if response.blank?

        response.error_payload.to_s.truncate(200)
      end
  end
end
