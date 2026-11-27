load Rails.root.join("app", "models", "banner.rb")

class Banner < ApplicationRecord
  audited
  has_associated_audits
  translation_class.class_eval do
    audited(
      associated_with: :globalized_model,
      only: %w[title description],
      if: ->(_translation) { Audit.translation_write_audited? }
    )
  end
end
