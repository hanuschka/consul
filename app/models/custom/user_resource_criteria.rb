class UserResourceCriteria < ApplicationRecord
  KINDS = %w[hard soft].freeze

  belongs_to :projekt_phase

  enum kind: { hard: "hard", soft: "soft" }

  validates :kind, :name, :ai_instruction, presence: true

  scope :ordered, -> { order(:kind, :position) }
  scope :hard_kind, -> { where(kind: "hard").order(:position) }
  scope :soft_kind, -> { where(kind: "soft").order(:position) }

  default_scope { ordered }

  before_validation :assign_default_position

  def display_text
    name.presence || read_attribute(:text)
  end

  private

    def assign_default_position
      return if position.present?
      return if projekt_phase_id.blank?

      max = self.class.unscoped.where(projekt_phase_id: projekt_phase_id, kind: kind).maximum(:position)
      self.position = max.to_i + 1
    end
end
