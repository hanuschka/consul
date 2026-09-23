class Kern::Table::InlineActionComponent < ApplicationComponent
  STYLE_CLASSES = {
    default: "",
    edit: "kern-table__inline-action--edit",
    delete: "kern-table__inline-action--delete"
  }.freeze

  def initialize(label:, url:, style: :default, icon: nil, **options)
    @label = label
    @url = url
    @style = style.to_sym
    @icon = Kern::Table::ActionOptions.icon(explicit_icon: icon, style: @style, label: label)
    @options = Kern::Table::ActionOptions.with_turbo_method(options)
  end

  def render?
    @options.delete(:show) != false
  end

  def css_classes
    [
      "round-icon-button",
      "kern-table__inline-action",
      "text-decoration-none",
      STYLE_CLASSES[@style]
    ].compact_blank.join(" ")
  end
end
