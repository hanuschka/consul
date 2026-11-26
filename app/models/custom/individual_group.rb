class IndividualGroup < ApplicationRecord
  translates :name, touch: true
  include Globalizable
  include MachineTranslatable

  audited only: %i[kind visible]
  has_associated_audits
  translation_class.class_eval do
    audited(
      associated_with: :globalized_model,
      only: IndividualGroup.translated_attribute_names,
      if: ->(_translation) { Audit.translation_write_audited? }
    )
  end

  has_many :individual_group_values, dependent: :destroy
  validates :name, presence: true

  enum :kind, { hard: 0, soft: 1 }

  scope :hard, -> { where(kind: "hard") }
  scope :soft, -> { where(kind: "soft") }
  scope :visible, -> { where(visible: true) }
end
