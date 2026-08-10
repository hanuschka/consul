class Whatsapp::Platform::ConfigureConversationalComponentsService < ApplicationService
  # Ice breakers, commands and the welcome trigger live on the phone number at
  # Meta, not in our database, so every copy change has to be pushed again.
  def call
    return if !::Whatsapp.configured?

    response =
      ::WhatsappApi::Client
        .new
        .conversational_automation
        .configure(
          enable_welcome_message: ::Whatsapp.welcome_message_enabled?,
          prompts: ::Whatsapp.ice_breakers,
          commands: ::Whatsapp.commands
        )

    log(response)

    response
  end

  private

    def log(response)
      if response.success?
        Rails.logger.info("[Whatsapp] conversational components applied")
      else
        Rails.logger.error("[Whatsapp] conversational components failed: #{response.code}")
      end
    end
end
