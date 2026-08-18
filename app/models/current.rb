# frozen_string_literal: true

class Current < ActiveSupport::CurrentAttributes
  attribute :settings
  attribute :i18n_content_translations
  attribute :visible_projekt_ids
  attribute :site_customization_images
  attribute :custom_content_blocks
  attribute :content_card_projekt_buckets
  attribute :whatsapp_phrase_sets
  attribute :whatsapp_message_context
  attribute :multiple_registered_address_cities
  attribute :registered_address_first_city_names
end
