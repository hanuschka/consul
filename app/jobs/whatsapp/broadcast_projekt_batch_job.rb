class Whatsapp::BroadcastProjektBatchJob < ApplicationJob
  queue_as :default

  def perform(projekt_id, account_ids)
    projekt = Projekt.find_by(id: projekt_id)

    return if projekt.blank?
    return if !::Whatsapp.enabled?

    template_name = ::Whatsapp.broadcast_template_name

    return if template_name.blank?

    deliver(projekt, template_name, account_ids)
  end

  private

    def deliver(projekt, template_name, account_ids)
      variables = [projekt_title(projekt), projekt_url(projekt)]

      WhatsappAccount.subscribed.where(id: account_ids).find_each do |account|
        next if WhatsappMessage.broadcast_delivered?(account.id, projekt.id)

        Whatsapp::Outbound.template(
          account: account,
          name: template_name,
          variables: variables,
          projekt_id: projekt.id
        )
      end
    end

    def projekt_title(projekt)
      projekt.page&.title.presence || projekt.name
    end

    def projekt_url(projekt)
      Rails.application.routes.url_helpers.projekt_url(projekt, **UrlOptions.default.to_h)
    end
end
