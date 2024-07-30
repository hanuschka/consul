class SiteCustomization::ContentCard < ApplicationRecord
  KINDS = %w[
    current_polls
    active_projekts
    latest_resources
    projekts_map
    events
    expired_polls
    widget_cards
  ].freeze

  translates :title, touch: true
  include Globalizable

  def self.for_homepage
    KINDS.map do |kind|
      find_or_create_by!(kind: kind) do |card|
        card.title = default_titles[kind]
        card.settings = default_settings[kind] || {}
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
      "current_polls" => "Laufende Abstimmungen",
      "active_projekts" => "Aktive Projekte",
      "latest_resources" => "Neueste Beiträge (Diskussionen, Vorschläge, Investitionsvorschläge)",
      "projekts_map" => "Projektkarte",
      "events" => "Veranstaltungen",
      "expired_polls" => "Abgeschlossene Abstimmungen",
      "widget_cards" => "Individuelle Kacheln"
    }
  end

  def self.default_settings
    {
      "current_polls" => {
        "polls_limit" => 3
      },
      "latest_resources" => {
        "debates_limit" => 3,
        "proposals_limit" => 3,
        "investments_limit" => 3
      }
    }
  end
end
