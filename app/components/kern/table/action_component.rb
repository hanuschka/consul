class Kern::Table::ActionComponent < ApplicationComponent
  STYLE_CLASSES = {
    default: "",
    edit: "kern-table__actions-menu-item--edit",
    delete: "kern-table__actions-menu-item--delete"
  }.freeze

  def initialize(label:, url:, style: :default, divider: false, icon: nil, **options)
    @label = label
    @url = url
    @style = style.to_sym
    @divider = divider
    @icon = Kern::Table::ActionOptions.icon(explicit_icon: icon, style: @style, label: label)
    @options = Kern::Table::ActionOptions.with_turbo_method(options)
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
      STYLE_CLASSES[@style]
    ].compact_blank.join(" ")
  end

  def divider?
    @divider
  end
end
