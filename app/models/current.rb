# frozen_string_literal: true

class Current < ActiveSupport::CurrentAttributes
  attribute :settings
  attribute :i18n_content_translations
  attribute :visible_projekt_ids
  attribute :site_customization_images
  attribute :custom_content_blocks
  attribute :content_card_projekt_buckets
end
