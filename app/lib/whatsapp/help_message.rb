module Whatsapp::HelpMessage
  # What "Hilfe" answers with, whether the pill was tapped, the word was typed or the
  # assistant was asked what it can do. Fixed copy rather than the model's, because
  # it has to name the same words, the same privacy page and the same contact every
  # time; what the citizen does after it is the assistant's again, since every pill
  # below it is an ordinary catalog tap.
  #
  # Three pills, which is every slot a message has: the main-menu pill is left off on
  # purpose, so a help message tapped open mid-draft offers nothing that resets it.
  STARTER_ACTIONS = %i[submit_proposal discover my_contributions].freeze

  module_function

  def deliver(conversation)
    account = conversation.whatsapp_account

    ::Whatsapp::Send.locale_buttons(
      account: account, body: body(account), buttons: starter_pills
    )
  end

  def body(account)
    help = ::Whatsapp.copy(
      "whatsapp.bot.help.body",
      privacy_url: ::Whatsapp::PortalLinks.privacy_url(locale: ::Whatsapp.locale_for(account))
    )

    return help if contact.blank?

    [help, ::Whatsapp.copy("whatsapp.bot.help.contact", contact: contact)].join("\n")
  end

  # Left out rather than filled with the portal's contact page when the settings are
  # empty: the help names the administration only where it has said how to reach it.
  def contact
    [
      ::Whatsapp.administration_contact_phone,
      ::Whatsapp.administration_contact_email,
      ::Whatsapp.administration_contact_url
    ].compact.join(", ").presence
  end

  def starter_pills
    STARTER_ACTIONS.map do |action|
      {
        id: ::Whatsapp::FlowActions.id_for(action: action),
        title: ::Whatsapp.copy("whatsapp.bot.buttons.#{action}")
      }
    end
  end

  private_class_method :body, :contact, :starter_pills
end
