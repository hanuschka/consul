# frozen_string_literal: true

class Shared::ResourcesListComponent < ApplicationComponent
  renders_one :bottom_content

  attr_reader :filters, :remote_url, :resource_type, :resources

  def initialize(
    resources:,
    resource_type: nil,
    title: nil,
    title_link: nil,
    resources_name: nil,
    filters: nil,
    current_filter: nil,
    remote_url: nil,
    map_coordinates: nil,
    css_class: nil,
    filter_title: nil,
    empty_list_text: nil,
    filter_param: nil,
    hide_actions: false,
    hide_title: false,
    only_content: false,
    text_search_enabled: false,
    additional_data: {}
  )
    @resources = resources
    @resource_type = resource_type
    @title = title
    @title_link = title_link
    # @filters = filters.presence || default_filter_options
    @filters = filters
    @current_filter = current_filter
    @remote_url = remote_url
    @only_content = only_content
    @map_coordinates = map_coordinates
    @css_class = css_class
    @hide_title = hide_title
    @text_search_enabled = text_search_enabled
    @empty_list_text = empty_list_text
    @filter_param = filter_param
    @filter_title = filter_title.presence || "Sortieren nach"
    @hide_actions = hide_actions
    @additional_data = additional_data
  end

  def wide?
    helpers.cookies["wide_resources"] == "true" || @wide
  end

  def class_names
    base = @css_class.to_s

    if wide?
      base += " -wide"
    end

    base
  end

  def selected_filter_otpion
    return if filters.blank?

    filters.find { |filter| filter == @current_filter }
  end

  def i18n_namespace
    if resource_type == Projekt
      "custom.projekts"
    elsif resource_type == Debate
      "debates.index"
    elsif resource_type == Proposal
      "proposals.index"
    elsif resource_type == Budget::Investment
      "budget.investment.index"
    end
  end

  def switch_view_mode_icon
    wide? ? "fa-grip-vertical" : "fa-bars"
  end

  def resource_component(resource)
    case resource
    when Projekt
      Projekts::ListItemComponent.new(projekt: resource)
    when Proposal
      Proposals::ListItemComponent.new(proposal: resource)
    when Debate
      Debates::ListItemComponent.new(debate: resource)
    when Poll
      Polls::ListItemComponent.new(poll: resource)
    when DeficiencyReport
      DeficiencyReports::ListItemComponent.new(deficiency_report: resource)
    when Budget::Investment
      Budgets::Investments::ListItemComponent.new(
        budget_investment: resource,
        ballot: @additional_data[:ballot],
        top_level_active_projekts: @additional_data[:top_level_active_projekts],
        top_level_archived_projekts: @additional_data[:top_level_archived_projekts]
      )
    when ProjektEvent
      ProjektEvents::ListItemComponent.new(projekt_event: resource)
    end
  end

  def default_filter_options
    [
      "newest",
      "oldest"
    ]
  end
end