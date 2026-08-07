module Adm
  class WhatsappController < Adm::BaseController
    FEATURE_SETTING_KEYS = %w[
      feature.whatsapp_bot
    ].freeze

    WELCOME_SETTING_KEY = "whatsapp.welcome_message_enabled".freeze
    GREETING_SETTING_KEY = "whatsapp.welcome_greeting".freeze
    COMMANDS_SETTING_KEY = "whatsapp.commands".freeze

    ICE_BREAKER_SETTING_KEYS =
      (1..::Whatsapp::MAX_ICE_BREAKERS).map { |position| "whatsapp.ice_breaker_#{position}" }.freeze

    AUTO_BROADCAST_SETTING_KEY = "whatsapp.auto_broadcast_new_projekts".freeze

    TEXT_SETTING_KEYS = %w[
      whatsapp.default_locale
      whatsapp.broadcast_template
      whatsapp.broadcast_card_template
      whatsapp.broadcast_template_language
      whatsapp.transcription_model
      whatsapp.message_retention_days
      whatsapp.max_voice_megabytes
    ].freeze

    DIALOGS_PER_PAGE = 20
    DIALOGS_FRAME_ID = "whatsapp_dialogs".freeze

    DEFAULT_TAB = "connection".freeze
    TEMPLATES_TAB = "templates".freeze
    DEFAULT_TEMPLATE_NAME = "neues_projekt".freeze

    # PDF QR poster disabled for now. Restoring it means uncommenting, in this
    # file: the constant below, the `except: :qr_poster` filter, the qr_poster
    # action and the four private helpers at the bottom — plus the route in
    # config/routes/adm.rb and the download button in
    # Adm::WhatsappQrCodeComponent. It also needs `qr_token_subject` back: read
    # the token through QrToken.projekt_phase_id_from, else projekt_id_from, and
    # return the ProjektPhase or Projekt it names, so a poster request cannot be
    # pointed at an arbitrary projekt by editing the URL.
    # QR_POSTER_MODULE_SIZE = 14

    before_action :authorize_settings # , except: :qr_poster
    before_action :load_configured_state

    def show
      return render_dialogs_frame if dialogs_frame_request?

      load_show_data
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
    #   subject = token.present? ? qr_token_subject(token) : nil
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

    def configure_conversational_components
      return head :forbidden if !@configured

      response = ::Whatsapp::ConfigureConversationalComponentsService.call

      if response&.success?
        flash[:success] = t("adm.whatsapp.conversational_components.applied")
      else
        flash[:error] = t("adm.whatsapp.conversational_components.failed",
          error: response&.admin_error_message || t("adm.whatsapp.not_configured"))
      end

      redirect_to adm_whatsapp_path
    end

    def create_template
      @template_form = WhatsappTemplateForm.new(template_params)

      return render_template_form_errors if @template_form.invalid?

      response =
        ::Whatsapp::BroadcastTemplates.create(
          name: @template_form.name,
          language: @template_form.language,
          body: @template_form.body
        )

      if !response&.success?
        @template_form.errors.add(
          :base,
          response&.admin_error_message || t("adm.whatsapp.not_configured")
        )

        return render_template_form_errors
      end

      flash[:success] = t("adm.whatsapp.template.submitted")

      redirect_to adm_whatsapp_path(tab: TEMPLATES_TAB)
    end

    # The only path that activates a broadcast template, now that creating one
    # no longer does: it runs after Meta reports the template approved, and it
    # writes the language alongside the name so the pair cannot drift.
    def use_template
      setting_key = ::Whatsapp::BroadcastTemplates::SETTING_KEYS_BY_KIND[template_kind]

      Setting[setting_key] = params[:name].to_s
      Setting["whatsapp.broadcast_template_language"] = params[:language].to_s

      flash[:success] = t("adm.whatsapp.template.selected", name: params[:name])

      redirect_to adm_whatsapp_path(tab: TEMPLATES_TAB)
    end

    private

      def authorize_settings
        authorize [:adm, Setting], :update?
      end

      # Anything unrecognised is the text template: a wrong kind would write the
      # name into the setting the other variant reads.
      def template_kind
        kind = params[:kind].to_s

        return kind if ::Whatsapp::BroadcastTemplates::SETTING_KEYS_BY_KIND.key?(kind)

        ::Whatsapp::BroadcastTemplates::TEXT_KIND
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

      # Filtering and pagination happen inside the dialogs turbo-frame, so those
      # requests render the list alone — skipping the six other tab panels and
      # the two 360dialog round-trips load_integration_state would make.
      def dialogs_frame_request?
        @configured && turbo_frame_request_id == DIALOGS_FRAME_ID
      end

      def render_dialogs_frame
        load_dialogs

        render partial: "adm/whatsapp/dialogs_frame", layout: false
      end

      def load_show_data
        @active_tab ||= DEFAULT_TAB
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
        load_template_form
      end

      def load_template_form
        @template_form ||= WhatsappTemplateForm.new(
          name: DEFAULT_TEMPLATE_NAME,
          language: ::Whatsapp.broadcast_template_language,
          body: t("adm.whatsapp.show.template_body_default")
        )
      end

      def template_params
        params.require(:template).permit(:name, :language, :body)
      end

      def render_template_form_errors
        @active_tab = TEMPLATES_TAB
        load_show_data

        render :show, status: :unprocessable_entity
      end

      def load_settings
        settings_by_key = Setting.where(key: all_setting_keys).index_by(&:key)

        @feature_settings = FEATURE_SETTING_KEYS.filter_map { |key| settings_by_key[key] }
        @text_settings = TEXT_SETTING_KEYS.filter_map { |key| settings_by_key[key] }
        @auto_broadcast_setting = settings_by_key[AUTO_BROADCAST_SETTING_KEY]
        @entry_settings = entry_settings(settings_by_key)
      end

      # Editor kind varies per field, so the tab renders pairs rather than one
      # uniform list: a switch, free text, four short lines and a command block.
      def entry_settings(settings_by_key)
        pairs = [
          [settings_by_key[WELCOME_SETTING_KEY], :boolean],
          [settings_by_key[GREETING_SETTING_KEY], :text],
          *ICE_BREAKER_SETTING_KEYS.map { |key| [settings_by_key[key], :string] },
          [settings_by_key[COMMANDS_SETTING_KEY], :text]
        ]

        pairs.select { |setting, _kind| setting.present? }
      end

      def all_setting_keys
        FEATURE_SETTING_KEYS + TEXT_SETTING_KEYS + ICE_BREAKER_SETTING_KEYS +
          [WELCOME_SETTING_KEY, GREETING_SETTING_KEY, COMMANDS_SETTING_KEY,
           AUTO_BROADCAST_SETTING_KEY]
      end

      def load_eligible_phases
        @eligible_projekt_phases = WhatsappEligiblePhasesQuery.call
      end

      # Two 360dialog round-trips, each retried three times with a sleep at a
      # 20-second timeout, so a gateway returning 502 used to cost the page a
      # couple of minutes with the worker blocked throughout. Both answers are
      # configuration that changes on the order of hours, so they are cached for
      # a minute — and only when the call actually came back, because both
      # services report failure as an empty or unreachable value that must not
      # be remembered.
      INTEGRATION_STATE_TTL = 1.minute

      def load_integration_state
        @webhook_status = cached_integration_state("webhook_status") do
          ::Whatsapp::WebhookStatusService.call(expected_base_url: request.base_url)
        end

        @templates = cached_integration_state("templates") { ::Whatsapp::BroadcastTemplates.list }
      end

      def cached_integration_state(key, &block)
        cache_key = "whatsapp/integration_state/#{key}"
        cached = Rails.cache.read(cache_key)

        return cached if cached.present?

        value = block.call

        Rails.cache.write(cache_key, value, expires_in: INTEGRATION_STATE_TTL) if usable?(value)

        value
      end

      def usable?(value)
        return value[:reachable].present? if value.is_a?(Hash)

        value.present?
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
  end
end
