module Kern::Table::ActionOptions
  STYLE_ICONS = {
    edit: "edit",
    delete: "delete"
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

  FALLBACK_ICON = "arrow_forward".freeze

  def self.icon(explicit_icon:, style:, label:)
    explicit_icon || STYLE_ICONS[style] || icon_from_label(label)
  end

  def self.with_turbo_method(options)
    method = options[:method]
    return options if method.blank?

    options.except(:method).deep_merge(data: { turbo_method: method })
  end

  def self.icon_from_label(label)
    normalized = label.to_s.downcase
    LABEL_ICON_MAP.each do |keyword, mapped_icon|
      return mapped_icon if normalized.include?(keyword)
    end

    FALLBACK_ICON
  end
  private_class_method :icon_from_label
end
