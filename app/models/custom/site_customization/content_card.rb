load Rails.root.join("app", "models", "site_customization", "content_card.rb")

class SiteCustomization::ContentCard < ApplicationRecord
  audited only: %i[active given_order settings], on: %i[update destroy]
  has_associated_audits
  translation_class.class_eval do
    audited(
      associated_with: :globalized_model,
      only: %w[title],
      if: ->(_translation) { Audit.translation_write_audited? }
    )
  end
end
