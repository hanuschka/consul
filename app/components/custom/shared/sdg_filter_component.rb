class Shared::SDGFilterComponent < ApplicationComponent
  def initialize(class_name, sdgs: [])
    @class_name = class_name
    @sdgs = sdgs
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

  def goals
    SDG::Goal.order(:code)
  end

  def parameter_name
    if @sdgs.first.is_a?(SDG::Goal)
      "goal"
    else
      "target"
    end
  end

  def link_list_sdg_goals(*links, **options)
    tag.ul(options) do
      safe_join(links.select(&:present?).map do |text, url, current = false, **link_options|
        goal_code = link_options[:data].present? ? link_options[:data][:code] : nil

        active_class = highlight_sdg_chip(goal_code) ? "selected-goal" : "unselected-goal"

        js_class = goal_code.class.name == "Integer" ? "js-sdg-custom-goal-filter" : "js-sdg-custom-target-filter"

        tag.li(class: "#{js_class} #{active_class}") do
          link_to text, "", link_options
        end
      end, "\n")
    end
  end

  def links
    # [*sdg_links, see_more_link]
    [*sdg_links]
  end

  def sdg_links
    @sdgs.map do |goal_or_target|
      [
        render(SDG::TagComponent.new(goal_or_target)),
        index_by(parameter_name => goal_or_target.code),
        title: filter_text(goal_or_target),
        data: { code: goal_or_target.code }
      ]
    end
  end

  def filter_text(goal_or_target)
    t("sdg.#{i18n_namespace}.filter.link",
      resources: related_model.model_name.human(count: :other),
      code: goal_or_target.code)
  end

  def index_by(advanced_search)
    '#'
    # if related_model.name == "Legislation::Proposal"
    #   legislation_process_proposals_path(params[:id], advanced_search: advanced_search, filter: params[:filter])
    # else
    #   polymorphic_path(related_model, advanced_search: advanced_search)
    # end
  end
end
