class SectionContactPerson < ApplicationRecord
  SECTIONS = %w[ideas deficiency_reports projekts moderation valuation landing_pages].freeze

  belongs_to :user, touch: true

  delegate :name, to: :user

  validates :section, presence: true, inclusion: { in: SECTIONS }
  validates :user_id, presence: true

  scope :for_section, ->(section) { where(section: section).includes(user: :image).order(:position) }
end
