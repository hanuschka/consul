class Sidebar::SdgsCardComponent < ApplicationComponent
  def initialize(sdgs:, sdg_targets:)
    @sdgs = sdgs
    @sdg_targets = sdg_targets
  end

  def render?
    Setting["feature.sdg"] && @sdgs.present? && @sdg_targets.present?
  end
end
