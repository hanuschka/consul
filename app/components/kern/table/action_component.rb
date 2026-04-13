class Kern::Table::ActionComponent < ApplicationComponent
  STYLES = {
    default: { icon: nil, css_class: "" },
    edit: { icon: "edit", css_class: "kern-table__actions-menu-item--edit" },
    delete: { icon: "delete", css_class: "kern-table__actions-menu-item--delete" }
  }.freeze

  LABEL_ICON_MAP = {
    "show" => "visibility", "anzeigen" => "visibility", "details" => "visibility",
    "edit" => "edit", "bearbeiten" => "edit",
    "delete" => "delete", "löschen" => "delete", "entfernen" => "delete", "remove" => "delete",
    "open" => "open_in_new", "öffnen" => "open_in_new", "website" => "open_in_new", "frontend" => "open_in_new",
    "hide" => "visibility_off", "verbergen" => "visibility_off", "ausblenden" => "visibility_off",
    "unhide" => "visibility", "einblenden" => "visibility", "wiederherstellen" => "visibility",
    "ignore" => "do_not_disturb_on", "ignorieren" => "do_not_disturb_on",
    "audit" => "history", "verlauf" => "history",
    "map" => "map", "karte" => "map",
    "vote" => "how_to_vote", "abstimm" => "how_to_vote",
    "send" => "send", "senden" => "send", "versenden" => "send", "notification" => "send", "benachrichtig" => "send",
    "download" => "download", "pdf" => "download",
    "milestone" => "flag", "meilenstein" => "flag",
    "progress" => "bar_chart", "fortschritt" => "bar_chart",
    "feedback" => "rate_review",
    "manage" => "settings", "verwalten" => "settings", "bewert" => "settings",
    "team" => "group", "manager" => "group", "people" => "group",
    "phase" => "dashboard_customize", "sichtbar" => "tune",
    "key" => "key", "schlüssel" => "key",
    "answer" => "question_answer", "antwort" => "question_answer"
  }.freeze

  def initialize(label:, url:, style: :default, divider: false, icon: nil, **options)
    @label = label
    @url = url
    @style = style.to_sym
    @divider = divider
    @icon = icon || STYLES.dig(@style, :icon) || icon_from_label(label)
    @options = options
  end

  def render?
    @options.delete(:show) != false
  end

  def css_classes
    [
      "kern-table__actions-menu-item",
      "text-decoration-none",
      "d-flex",
      "align-items-center",
      "gap-2",
      "p-1",
      "px-3",
      STYLES.dig(@style, :css_class)
    ].compact.join(" ")
  end

  def divider?
    @divider
  end

  private

    def icon_from_label(label)
      normalized = label.to_s.downcase
      LABEL_ICON_MAP.each do |keyword, icon|
        return icon if normalized.include?(keyword)
      end
      "arrow_forward"
    end
end
