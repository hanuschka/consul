class Whatsapp::BroadcastProjektBatchJob < ApplicationJob
  queue_as :default
  queue_with_priority ::Whatsapp::BULK_PRIORITY

  def perform(projekt_id, account_ids)
    @projekt = Projekt.find_by(id: projekt_id)

    return if @projekt.blank?
    return if !::Whatsapp.enabled?
    return if ::Whatsapp.broadcast_template_name.blank?
    return if !Whatsapp::BroadcastGuards.still_published?(@projekt, context: "broadcast batch")

    deliver(account_ids)
  end

  private

    # Everything the message is built from is the same for all fifty accounts in
    # the batch, so it is resolved once: the template names and the language are
    # uncached Setting reads, and the signed blob URL is an HMAC per call.
    def deliver(account_ids)
      accounts = Whatsapp::Account.subscribed_to(:new_projekt).where(id: account_ids)
      pending = accounts.where.not(id: already_delivered_account_ids(account_ids))

      pending.find_each { |account| deliver_to(account) }
    end

    def already_delivered_account_ids(account_ids)
      Whatsapp::Message
        .where(
          whatsapp_account_id: account_ids,
          projekt_id: @projekt.id,
          kind: "template",
          direction: "outbound"
        )
        .where.not(status: "failed")
        .distinct
        .pluck(:whatsapp_account_id)
    end

    def deliver_to(account)
      return deliver_text(account) if !card_deliverable?

      Whatsapp::Send.card_template(
        account: account,
        name: card_template_name,
        image_url: card_image_url,
        variables: [projekt_title, card_subtitle],
        button_variable: @projekt.id,
        projekt_id: @projekt.id
      )
    end

    def deliver_text(account)
      Whatsapp::Send.template(
        account: account,
        name: text_template_name,
        variables: [projekt_title, projekt_url],
        projekt_id: @projekt.id
      )
    end

    # Every part of the card has to be there before it is worth sending as one:
    # an approved card template, a picture Meta will accept, and a subtitle for
    # the second body variable — Meta rejects a template parameter that is empty.
    def card_deliverable?
      return @card_deliverable if defined?(@card_deliverable)

      @card_deliverable =
        card_template_name.present? && card_subtitle.present? && card_image_url.present?
    end

    def card_template_name
      return @card_template_name if defined?(@card_template_name)

      @card_template_name = ::Whatsapp.broadcast_card_template_name
    end

    def text_template_name
      @text_template_name ||= ::Whatsapp.broadcast_template_name
    end

    def card_subtitle
      return @card_subtitle if defined?(@card_subtitle)

      @card_subtitle = Whatsapp::ProjektCard.subtitle(@projekt)
    end

    def card_image_url
      return @card_image_url if defined?(@card_image_url)

      @card_image_url = Whatsapp::ProjektCard.image_url(@projekt)
    end

    def projekt_title
      @projekt_title ||= Whatsapp::ProjektLink.title(@projekt)
    end

    def projekt_url
      @projekt_url ||= Whatsapp::ProjektLink.url(@projekt)
    end
end
