class Whatsapp::BroadcastProjektBatchJob < ApplicationJob
  queue_as :default

  # Meta fetches the header image itself and rejects anything it cannot render
  # as a template image, so a projekt whose picture is a webp or oversized file
  # gets the plain text message instead of a broken card.
  CARD_IMAGE_CONTENT_TYPES = ["image/jpeg", "image/png"].freeze
  CARD_IMAGE_MAX_BYTES = 5.megabytes
  CARD_SUBTITLE_MAX_LENGTH = 900

  def perform(projekt_id, account_ids)
    projekt = Projekt.find_by(id: projekt_id)

    return if projekt.blank?
    return if !::Whatsapp.enabled?
    return if ::Whatsapp.broadcast_template_name.blank?
    return if !still_published?(projekt)

    deliver(projekt, account_ids)
  end

  private

    def still_published?(projekt)
      return true if projekt.meets_publish_criteria?

      Rails.logger.info(
        "[Whatsapp] broadcast batch for projekt #{projekt.id} skipped: no longer published"
      )

      false
    end

    def deliver(projekt, account_ids)
      WhatsappAccount.subscribed.where(id: account_ids).find_each do |account|
        next if WhatsappMessage.broadcast_delivered?(account.id, projekt.id)

        if card_deliverable?(projekt)
          deliver_card(projekt, account)
        else
          deliver_text(projekt, account)
        end
      end
    end

    def deliver_card(projekt, account)
      Whatsapp::Outbound.card_template(
        account: account,
        name: ::Whatsapp.broadcast_card_template_name,
        image_url: card_image_url(projekt),
        variables: [projekt_title(projekt), card_subtitle(projekt)],
        button_variable: projekt.id,
        projekt_id: projekt.id
      )
    end

    def deliver_text(projekt, account)
      Whatsapp::Outbound.template(
        account: account,
        name: ::Whatsapp.broadcast_template_name,
        variables: [projekt_title(projekt), projekt_url(projekt)],
        projekt_id: projekt.id
      )
    end

    # Every part of the card has to be there before it is worth sending as one:
    # an approved card template, a picture Meta will accept, and a subtitle for
    # the second body variable — Meta rejects a template parameter that is empty.
    def card_deliverable?(projekt)
      return @card_deliverable if defined?(@card_deliverable)

      @card_deliverable =
        ::Whatsapp.broadcast_card_template_name.present? &&
        card_subtitle(projekt).present? &&
        card_image(projekt).present?
    end

    def card_subtitle(projekt)
      return @card_subtitle if defined?(@card_subtitle)

      @card_subtitle = projekt.page&.subtitle.to_s.squish.truncate(CARD_SUBTITLE_MAX_LENGTH).presence
    end

    def card_image(projekt)
      return @card_image if defined?(@card_image)

      attachment = projekt.page&.image&.attachment

      @card_image = attachment if usable_card_image?(attachment)
    end

    def usable_card_image?(attachment)
      return false if attachment.blank? || !attachment.attached?
      return false if !CARD_IMAGE_CONTENT_TYPES.include?(attachment.blob.content_type)

      attachment.blob.byte_size <= CARD_IMAGE_MAX_BYTES
    end

    def card_image_url(projekt)
      Rails.application.routes.url_helpers.rails_blob_url(
        card_image(projekt),
        **UrlOptions.default.to_h
      )
    end

    def projekt_title(projekt)
      Whatsapp::ProjektLink.title(projekt)
    end

    def projekt_url(projekt)
      Whatsapp::ProjektLink.url(projekt)
    end
end
