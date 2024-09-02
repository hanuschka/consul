module ResourceBelongsToProjekt
  extend ActiveSupport::Concern

  included do
    scope :by_projekt_id, ->(projekt_ids) {
      joins(projekt_phase: :projekt)
        .where(projekts: { id: projekt_ids })
    }

    scope :with_phase_feature, ->(feature_key) {
      joins(projekt_phase: :settings)
        .where(settings: { key: "feature.#{feature_key}", value: "active" })
    }
  end
end
