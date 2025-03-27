class SiteCustomization::ContentCard < ApplicationRecord
  KINDS = %w[
    active_projekts
    current_projekts
    latest_user_activity
    current_polls
    latest_resources
    expired_projekts
    events
  ].freeze

  translates :title, touch: true
  include Globalizable

  scope :active, -> { where(active: true) }
  scope :homepage, -> { where(landing_page_id: nil) }
  scope :for_landing_page, -> (landing_page_id) { where(landing_page_id: landing_page_id) }

  default_scope { order(:given_order) }

  def self.get_or_create_for_homepage
    get_or_create
  end

  def self.get_or_create_for_landing_page(landing_page_id)
    get_or_create(landing_page_id: landing_page_id)
  end

  def self.get_or_create(landing_page_id: nil)
    kinds = KINDS

    if landing_page_id.present?
      kinds = kinds.excluding("latest_user_activity")
    end

    kinds.map do |kind|
      find_or_create_by_params = {
        kind: kind,
        landing_page_id: (landing_page_id.presence || nil)
      }

      find_or_create_by!(find_or_create_by_params) do |card|
        card.title = default_titles[kind]
        card.settings = default_settings[kind] || {}
        card.given_order = KINDS.index(kind) + 1
      end
    end.sort_by(&:given_order)
  end

  def self.order_content_cards(ordered_array)
    ordered_array.each_with_index do |card_id, order|
      find(card_id).update_column(:given_order, (order + 1))
    end
  end

  def self.default_titles
    {
      "active_projekts" => "Laufende Projekte",
      "current_projekts" => "Laufende Projekte mit aktiver Beteiligung",
      "latest_user_activity" => "Meine Aktivitäten",
      "current_polls" => "Laufende Abstimmungen",
      "latest_resources" => "Neueste Beiträge",
      "expired_projekts" => "Abgeschlossene Projekte",
      "events" => "Veranstaltungen"
    }
  end

  def self.default_settings
    {
      "active_projekts" => {
        "limit" => 3
      },
      "current_projekts" => {
        "limit" => 3
      },
      "latest_user_activity" => {},
      "current_polls" => {
        "limit" => 3
      },
      "latest_resources" => {
        "debates_limit" => 3,
        "proposals_limit" => 3,
        "investments_limit" => 3,
        "deficiency_reports_limit" => 0
      },
      "expired_projekts" => {
        "limit" => 3
      },
      "events" => {
        "limit" => 3
      }
    }
  end
end
