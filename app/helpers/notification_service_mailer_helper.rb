module NotificationServiceMailerHelper
  def notification_service_mailer_unsubscribe_block(action_name, projekt_phase: nil)
    if action_name == "new_proposal_notification"
      content_tag :p, style: "font-family: 'Open Sans','Helvetica Neue',arial,sans-serif; margin: 0;padding: 0;line-height: 1.5em;color: #222; font-size: 10px; margin-top: 12px;" do
        unsubscribe_from_new_proposal_notification
      end
    elsif projekt_phase.present?
      content_tag :p, style: "font-family: 'Open Sans','Helvetica Neue',arial,sans-serif; margin: 0;padding: 0;line-height: 1.5em;color: #222; font-size: 10px; margin-top: 12px;" do
        unsubscribe_from_phase(projekt_phase)
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

    def unsubscribe_from_phase(projekt_phase)
      url = page_url(projekt_phase.projekt.page.slug, projekt_phase_id: projekt_phase.id, anchor: "projekt-footer")
      t("custom.notification_service_mailers.shared.unsubscribe_html", url: url)
    end
end
