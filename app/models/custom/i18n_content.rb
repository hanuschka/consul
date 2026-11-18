load Rails.root.join("app", "models", "i18n_content.rb")

class I18nContent < ApplicationRecord
  EDITABLE_GROUPS = %i[
    debates community proposals polls layouts mailers management welcome machine_learning custom cli
    devise_views shared
  ].freeze

  # Machine translation stores its output in this table too, from background
  # jobs, so only the texts a client changes through the configuration API
  # are audited; otherwise every DeepL run would flood the audit trail.
  translation_class.class_eval do
    audited(
      associated_with: :globalized_model,
      only: :value,
      if: ->(_translation) { Current.api_client.present? }
    )
  end
  has_associated_audits

  def self.all_translation_strings
    I18n.backend.send(:init_translations) unless I18n.backend.initialized?

    all_groups = I18n.backend.send(:translations)[I18n.locale].select do |key, _translations|
      key.in?(EDITABLE_GROUPS)
    end

    flat_hash(all_groups).keys.map do |string|
      I18nContent.find_or_initialize_by(key: string)
    end
  end
end
