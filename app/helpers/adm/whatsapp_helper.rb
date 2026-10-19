module Adm
  module WhatsappHelper
    # Meta's own status strings, mapped to the four kern badge variants. Anything
    # unlisted is a status Meta added since: shown as info with the raw string,
    # which is still readable, rather than dropped or coloured as a guess.
    BADGE_STYLES = {
      "approved" => :success,
      "pending" => :warning,
      "submitted" => :warning,
      "in_appeal" => :warning,
      "pending_deletion" => :warning,
      "flagged" => :warning,
      "rejected" => :danger,
      "paused" => :danger,
      "disabled" => :danger
    }.freeze

    UNKNOWN_BADGE_STYLE = :info

    BOT_SWITCH_ANCHOR = "whatsapp-bot-switch".freeze

    # Names the missing secrets but never a value: the alert is shown to every
    # admin who can open the page.
    def whatsapp_blocking_reason_body(reason)
      t("adm.whatsapp.blocking_reasons.#{reason}.body", **whatsapp_blocking_reason_details(reason))
    end

    # Only where the page's own admin can fix it: the credentials and the AI
    # switch live in the server secrets, the provider key behind a policy
    # stricter than this page's.
    def whatsapp_blocking_reason_link(reason)
      case reason
      when :switched_off
        whatsapp_forward_link(
          t("adm.whatsapp.blocking_reasons.switched_off.link"),
          connection_adm_whatsapp_path(anchor: BOT_SWITCH_ANCHOR)
        )
      when :ai_provider_unavailable
        return if !Adm::AiSettingPolicy.new(current_user, Setting).index?

        whatsapp_forward_link(
          t("adm.whatsapp.blocking_reasons.ai_provider_unavailable.link"),
          adm_ai_settings_path
        )
      end
    end

    # The one representation of a template's status on the page. It exists
    # because the two tables used to disagree: an approved template got a badge
    # and an unsubmitted one got wrapping body text, so the same fact looked like
    # two different kinds of thing.
    #
    # A nil status is not missing data — it is the "never submitted" state, and
    # it gets a badge of its own rather than falling through to prose.
    def whatsapp_template_status_badge(status)
      status = status.to_s.downcase.presence

      return whatsapp_status_badge(:info, t("adm.whatsapp.show.notification_template_not_submitted")) if status.blank?

      whatsapp_status_badge(BADGE_STYLES.fetch(status, UNKNOWN_BADGE_STYLE), whatsapp_status_label(status))
    end

    # Where a slot has no status of its own, the slot itself says why — an empty
    # broadcast setting has no template for Meta to have an opinion about, while
    # an unsubmitted push does, because its name follows from the kind.
    MISSING_STATUS_LABEL_KEYS = {
      not_configured: "adm.whatsapp.show.slot_not_configured",
      not_submitted: "adm.whatsapp.show.notification_template_not_submitted"
    }.freeze

    def whatsapp_slot_status_badge(slot)
      label_key = MISSING_STATUS_LABEL_KEYS[slot[:missing_status]]

      return whatsapp_status_badge(:info, t(label_key)) if label_key.present?

      whatsapp_template_status_badge(slot[:status])
    end

    # Asked by the slot row, the push card and the account row, so the comparison
    # lives here rather than three times in ERB — rejected is the one status that
    # unlocks an action (delete, or a fresh submission).
    def whatsapp_template_rejected?(status)
      status.to_s.downcase == ::Whatsapp::BroadcastTemplates::REJECTED_STATUS
    end

    # Translated where the status is one Meta documents, and passed through
    # otherwise: an untranslated code says more than a missing-translation span.
    def whatsapp_status_label(status)
      key = "adm.whatsapp.show.template_statuses.#{status}"

      return t(key) if I18n.exists?(key)

      status
    end

    private

      def whatsapp_blocking_reason_details(reason)
        case reason
        when :missing_credentials
          keys = ::Whatsapp.missing_required_credential_keys.map { |key| "whatsapp.#{key}" }

          { keys: keys.join(", ") }
        when :ai_provider_unavailable
          { provider: ::Ai::Settings.current_llm_provider }
        else
          {}
        end
      end

      def whatsapp_forward_link(text, path)
        link_to(path, class: "kern-link") do
          safe_join([
            content_tag(:span, nil, class: "kern-icon kern-icon--arrow-forward", "aria-hidden": "true"),
            text
          ])
        end
      end

      def whatsapp_status_badge(style, label)
        content_tag(:span, class: "kern-badge kern-badge--#{style}") do
          content_tag(:span, label, class: "kern-label")
        end
      end
  end
end
