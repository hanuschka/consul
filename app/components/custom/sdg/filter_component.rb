class SDG::FilterComponent < ApplicationComponent
  attr_reader :class_name, :selected_sdg_goals, :sdg

  def initialize(class_name, selected_sdg_goals:, sdg_targets_for_selected_goals:, selected_sdg_targets: [])
    @class_name = class_name
    @selected_sdg_goals = selected_sdg_goals
    @sdg_targets_for_selected_goals = sdg_targets_for_selected_goals
    @selected_sdg_targets = selected_sdg_targets
  end

  def render?
    SDG::ProcessEnabled.new(class_name).enabled?
  end

  private

  # def selected_goals
    # return [] unless params[:sdg_goals].present?
    # params[:sdg_goals].split(',')
  # end

  def target_options
    if @selected_sdg_goals.present?
      selected_target =
        if @selected_sdg_targets.present?
          @selected_sdg_targets.first
        end

      options_from_collection_for_select(
        @sdg_targets_for_selected_goals,
        :code,
        :code,
        selected_target
      )
    end
  end

  def heading
    t("custom.sdg.goals.filter.heading")
  end

  def goals
    SDG::Goal.order(:code)
  end
end
