class Kern::Table::ActionComponent < ApplicationComponent
  STYLES = {
    default: { icon: nil, css_class: "" },
    edit: { icon: "edit", css_class: "kern-table__actions-menu-item--edit" },
    delete: { icon: "delete", css_class: "kern-table__actions-menu-item--delete" }
  }.freeze

  def initialize(label:, url:, style: :default, divider: false, icon: nil, **options)
    @label = label
    @url = url
    @style = style.to_sym
    @divider = divider
    @icon = icon || STYLES.dig(@style, :icon)
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
end
