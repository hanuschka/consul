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

      def whatsapp_status_badge(style, label)
        content_tag(:span, class: "kern-badge kern-badge--#{style}") do
          content_tag(:span, label, class: "kern-label")
        end
      end
  end
end
