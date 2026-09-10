module NotificationServiceMailerHelper
  # The mails a projekt subscription actually delivers. Contribution mails now
  # only reach administrators, moderators and projekt managers, so offering
  # them the citizen's subscription switch would point at a setting they never
  # turned on.
  PROJEKT_SUBSCRIPTION_ACTIONS = %w[
    new_poll projekt_arguments projekt_questions new_projekt_notification
    new_projekt_event new_projekt_milestone new_projekt_livestream
  ].freeze

  def notification_service_mailer_unsubscribe_block(action_name, projekt_phase: nil)
    if action_name == "new_proposal_notification"
      content_tag :p, style: "font-family: 'Open Sans','Helvetica Neue',arial,sans-serif; margin: 0;padding: 0;line-height: 1.5em;color: #222; font-size: 10px; margin-top: 12px;" do
        unsubscribe_from_new_proposal_notification
      end
    elsif projekt_phase.present? && PROJEKT_SUBSCRIPTION_ACTIONS.include?(action_name)
      content_tag :p, style: "font-family: 'Open Sans','Helvetica Neue',arial,sans-serif; margin: 0;padding: 0;line-height: 1.5em;color: #222; font-size: 10px; margin-top: 12px;" do
        unsubscribe_from_projekt(projekt_phase.projekt)
      end
    end
  end

  def css_for_mailer_quote
    "border-left: 2px solid #DEE0E3;font-style: italic;margin-left: 20px;padding:0px 10px;"
  end

  private

    def unsubscribe_from_new_proposal_notification
      t("custom.notification_service_mailers.new_proposal_notification.unsubscribe_html", url: proposal_url(@proposal))
    end

    def unsubscribe_from_projekt(projekt)
      t(
        "custom.notification_service_mailers.shared.unsubscribe_html",
        url: page_url(projekt.page.slug, anchor: "sidebar-projekt-subscription")
      )
    end
end
