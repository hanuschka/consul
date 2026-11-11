class Shared::StudioColorPickerComponent < ApplicationComponent
  RECENT_COLORS_LIMIT = 6

  # Every shade keeps white text at 4.5:1 or more and stands out at 3:1 or
  # more against light grey surfaces such as a progress bar track.
  PRESET_COLORS = {
    brand: "var(--brand-color, #1779ba)",
    navy: "#1a2e44",
    blue: "#1d4ed8",
    teal: "#0f766e",
    green: "#047857",
    olive: "#4d7c0f",
    amber: "#b45309",
    red: "#b91c1c",
    magenta: "#be185d",
    violet: "#6d28d9",
    slate: "#475569"
  }.freeze

  attr_reader :label, :picker_class

  def initialize(label:, picker_class: nil)
    @label = label
    @picker_class = picker_class
  end

  def css_classes
    ["studio-color-picker", "js-studio-color-picker", picker_class].compact.join(" ")
  end

  def preset_colors
    PRESET_COLORS.map do |color_key, color|
      {
        color: color,
        name: t("custom.projekts.page.studio_color_picker.colors.#{color_key}")
      }
    end
  end

  def default_custom_color
    PRESET_COLORS[:navy]
  end
end
