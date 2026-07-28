# frozen_string_literal: true

class Current < ActiveSupport::CurrentAttributes
  attribute :settings
  attribute :i18n_content_translations
  attribute :visible_projekt_ids
end
