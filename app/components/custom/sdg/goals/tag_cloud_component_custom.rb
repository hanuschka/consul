class SDG::Goals::TagCloudComponentCustom < ApplicationComponent
  attr_reader :class_name

  def initialize(class_name, sdg_targets: [])
    @class_name = class_name
    @sdg_targets = sdg_targets
  end

  def render?
    SDG::ProcessEnabled.new(class_name).enabled?
  end

  private

  def selected_goals
    return [] unless params[:sdg_goals].present?
    params[:sdg_goals].split(',')
  end

  def target_options
    if params[:sdg_goals]
      selected_target =
        if params[:sdg_targets].present?
          params[:sdg_targets].split(',').first
        end

      options_from_collection_for_select(@sdg_targets, :code, :code, selected_target)
    end
  end

  def heading
    t("custom.sdg.goals.filter.heading")
  end

  def goals
    SDG::Goal.order(:code)
  end
end
