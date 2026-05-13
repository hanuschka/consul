class SectionActivity < ApplicationRecord
  VALID_SECTIONS = Adm::Section::NAMES

  belongs_to :user, optional: true
  belongs_to :trackable, polymorphic: true, optional: true

  validates :section, presence: true, inclusion: { in: VALID_SECTIONS }
  validates :action, presence: true

  scope :for_section, ->(section) { where(section: section).includes(user: :image).order(created_at: :desc) }

  def self.log(user:, section:, trackable:, action:, metadata: {})
    create!(
      user: user,
      section: section,
      trackable: trackable,
      action: action,
      metadata: metadata
    )
  end
end
