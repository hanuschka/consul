class Whatsapp::Steps::SendMenuLinkService < ApplicationService
  # A tapped row can be minutes or weeks old, and both a projekt page and a
  # published evaluation can be withdrawn in between. So the id is resolved
  # through the same query that produced the row rather than trusted: an
  # evaluation that has since been hidden must not stay reachable through an
  # old message.
  def initialize(conversation:, row_id:)
    @conversation = conversation
    @row_id = row_id
  end

  def call
    return send_link(projekt_title(projekt), projekt_url(projekt)) if projekt.present?
    return send_result_link if result_projekt_phase.present?

    send_gone
  end

  private

    def account
      @conversation.whatsapp_account
    end

    def projekt
      return @projekt if defined?(@projekt)

      projekt_id = Whatsapp::MenuActions.projekt_id_from(@row_id)

      @projekt =
        if projekt_id.blank?
          nil
        else
          WhatsappBrowsableProjektsQuery.call.find { |candidate| candidate.id == projekt_id }
        end
    end

    def result_projekt_phase
      return @result_projekt_phase if defined?(@result_projekt_phase)

      projekt_phase_id = Whatsapp::MenuActions.projekt_phase_id_from(@row_id)

      @result_projekt_phase =
        if projekt_phase_id.blank?
          nil
        else
          WhatsappPublishedResultsQuery.call.find { |candidate| candidate.id == projekt_phase_id }
        end
    end

    def send_result_link
      send_link(projekt_title(result_projekt_phase.projekt), result_url(result_projekt_phase))
    end

    def send_link(title, url)
      body = I18n.t("whatsapp.bot.menu.link.body", title: title)

      message = Whatsapp::Outbound.cta_url(
        account: account,
        body: body,
        button_label: I18n.t("whatsapp.bot.buttons.open_projekt"),
        url: url
      )

      return message if message&.status == "sent"

      Whatsapp::Outbound.text(account: account, body: "#{body}\n\n#{url}")
    end

    def projekt_url(projekt)
      Whatsapp::ProjektLink.url(projekt)
    end

    def result_url(projekt_phase)
      Whatsapp::ProjektLink.evaluation_url(projekt_phase)
    end

    def projekt_title(projekt)
      Whatsapp::ProjektLink.title(projekt)
    end

    def send_gone
      Whatsapp::Outbound.recovery(
        conversation: @conversation,
        body: I18n.t("whatsapp.bot.menu.link.gone"),
        actions: [:menu]
      )
    end
end
