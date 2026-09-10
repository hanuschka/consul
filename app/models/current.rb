# frozen_string_literal: true

class Current < ActiveSupport::CurrentAttributes
  attribute :settings
  attribute :visible_projekt_ids
  attribute :site_customization_images
  attribute :custom_content_blocks
  attribute :content_card_projekt_buckets
  attribute :multiple_registered_address_cities
  attribute :registered_address_first_city_names

  # Whether a WhatsApp assistant turn is running in this job. Set by
  # Whatsapp::AiAssistant::RouterService and read by
  # Whatsapp::AiAssistant::ContinueConversationService, which must not start a turn
  # from inside one — see the note there. It sits here rather than travelling as an
  # argument because what reads it is several services below what sets it, and none of
  # those has any other reason to know a model is involved at all.
  attribute :whatsapp_assistant_turn_running
end
