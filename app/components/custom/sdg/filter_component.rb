class SDG::FilterComponent < ApplicationComponent
  attr_reader :class_name, :selected_sdg_goals, :sdg

  def initialize(class_name)
    @class_name = class_name

    @selected_sdg_goals = SDG::Goal.where(code: @selected_sdg_goals_codes)
    @sdg_targets_for_selected_goals = SDG::Target.where(goal: @selected_sdg_goals)
    @selected_sdg_targets = @sdg_targets_for_selected_goals.where(code: @selected_sdg_target_code)
  end

  def before_render
    @selected_sdg_goals_codes = params[:sdg_goals].present? ? params[:sdg_goals].split(",").map{ |code| code.to_i } : nil
    @selected_sdg_target_code = params[:sdg_targets].present? ? params[:sdg_targets].split(',')[0] : nil
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
