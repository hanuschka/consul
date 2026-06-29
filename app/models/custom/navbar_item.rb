require_dependency Rails.root.join("app", "models", "navbar_item").to_s

class NavbarItem < ApplicationRecord
  # Presets whose menu label should follow the feature's configurable name
  # (deficiency_reports.feature_name / ideas.feature_name) when no per-item
  # custom_title is set.
  PRESETS_WITH_FEATURE_NAME = %w[deficiency_reports ideas].freeze

  alias_method :consul_title, :title

  def title
    if kind == "presets" && custom_title.blank? && preset.in?(PRESETS_WITH_FEATURE_NAME)
      feature_name = Setting["#{preset}.feature_name"].presence
      return feature_name if feature_name
    end

    consul_title
  end
end
