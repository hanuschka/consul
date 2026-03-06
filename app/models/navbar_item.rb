class NavbarItem < ApplicationRecord
  PRESETS = {
    projekts: :projekts_path,
    events: :projekt_events_path,
    investments: :investments_path,
    proposals: :proposals_path,
    polls: :polls_path,
    deficiency_reports: :deficiency_reports_path,
    ideas: :ideas_path
  }.freeze

  has_many :children, class_name: "NavbarItem",
                      foreign_key: "parent_id",
                      dependent: :nullify,
                      inverse_of: :parent
  belongs_to :parent, class_name: "NavbarItem",
                      optional: true,
                      inverse_of: :children
  belongs_to :projekt, optional: true

  enum kind: { presets: 0, projekts: 1, external: 2 }

  validates :kind, presence: true

  scope :top_level, -> { where(parent_id: nil).order(:position) }

  def self.presets
    PRESETS
  end

  def self.projekts
    Projekt.all
  end

  def title
    case kind
    when "presets"
      I18n.t("navbar.presets.#{preset}")
    when "projekts"
      projekt.title
    when "external"
      external_title
    end
  end
end
