class NavbarItem < ApplicationRecord
  PRESETS = {
    deficiency_reports: :deficiency_reports_path,
    events: :projekt_events_path,
    ideas: :ideas_path,
    projekts: :projekts_path,
    investments: :investments_path,
    polls: :polls_path,
    proposals: :proposals_path
  }.freeze

  LANDING_PAGE_ALLOWED_PRESETS = %i[projekts events investments proposals polls].freeze

  PRESET_MODULE_SETTINGS = {
    deficiency_reports: "process.deficiency_reports",
    events: "extended_feature.general.enable_projekt_events_page",
    ideas: "process.ideas",
    projekts: "process.projekts",
    investments: "extended_feature.general.enable_investments_overview",
    polls: "process.polls",
    proposals: "process.proposals"
  }.freeze

  def self.enabled_presets
    PRESETS.reject do |key, _|
      setting_key = PRESET_MODULE_SETTINGS[key]
      setting_key.present? && !Setting[setting_key].present?
    end
  end

  has_many :children, class_name: "NavbarItem",
                      foreign_key: "parent_id",
                      dependent: :nullify,
                      inverse_of: :parent
  belongs_to :parent, class_name: "NavbarItem",
                      optional: true,
                      inverse_of: :children
  belongs_to :projekt, optional: true
  belongs_to :landing_page, class_name: "SiteCustomization::Page",
                            optional: true
  belongs_to :linked_page, class_name: "SiteCustomization::Page",
                           optional: true

  enum kind: { presets: 0, projekts: 1, external: 2, landing_pages: 3 }

  validates :kind, presence: true

  scope :top_level, -> { where(parent_id: nil).order(:position) }
  scope :global, -> { where(landing_page_id: nil) }
  scope :for_landing_page, ->(landing_page_id) { where(landing_page_id: landing_page_id) }

  def self.presets
    PRESETS
  end

  def self.projekts
    Projekt.all
  end

  def self.landing_pages_for_select(scope_landing_page = nil)
    scope = ::SiteCustomization::Page.landing.published
    scope = scope.where.not(id: scope_landing_page.id) if scope_landing_page.present?
    scope
  end

  def title
    return custom_title if custom_title.present?

    case kind
    when "presets"
      I18n.t("navbar.presets.#{preset}")
    when "projekts"
      projekt&.title || I18n.t("adm.navbar_items.deleted_projekt")
    when "landing_pages"
      linked_page&.title || I18n.t("adm.navbar_items.deleted_landing_page")
    end
  end

  def resource_missing?
    return true if kind == "projekts" && projekt.blank?
    return true if kind == "landing_pages" && linked_page.blank?

    false
  end
end
