class SectionSetting < ApplicationRecord
  SECTIONS = %w[ideas deficiency_reports projekts moderation valuation landing_pages officing].freeze

  belongs_to :author, class_name: "User", optional: true

  validates :section, presence: true, uniqueness: true, inclusion: { in: SECTIONS }
  validates :intro_text, length: { maximum: 350 }

  scope :for_section, ->(section) { find_or_initialize_by(section: section) }

  def intro_text_with_fallback
    intro_text.presence || I18n.t("adm.section_settings.intro_text_defaults.#{section}", default: nil)
  end
end
