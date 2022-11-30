class Shared::ResourcesList < ApplicationComponent
  renders_one :body

  def initialize(
    title:,
    map_coordinates: nil,
    resources:,
    resources_name: nil,
    filter_param: nil,
    filter_options: nil,
    current_filter_option: nil,
    resources_url: nil,
    only_content: false,
    wide: false, css_class: nil
  )
    @resources = resources
    @resources_name = resources_name
    @title = title
    @wide = wide
    @filter_param = filter_param.presence || "order"
    @filter_options = filter_options.presence || default_filter_options
    @current_filter_option = current_filter_option
    @resources_url = resources_url
    @only_content = only_content
    @css_class = css_class
  end

  def class_names
    base = @css_class.to_s

    if @wide
      base += " -wide"
    end

    base
  end

  def switch_view_mode_icon
    @wide ? "fa-grip-vertical" : "fa-bars"
  end

  def resource_component(resource)
    case resource
    when Projekt
      Projekts::ListItem.new(projekt: resource, wide: @wide)
    when Proposal
      Proposals::ListItem.new(proposal: resource, wide: @wide)
    when Debate
      Debates::ListItem.new(debate: resource, wide: @wide)
    when Poll
      Polls::ListItem.new(poll: resource, wide: @wide)
    when DeficiencyReport
      DeficiencyReports::ListItem.new(deficiency_report: resource, wide: @wide)
    when Budget::Investment
      Budgets::Investments::ListItem.new(budget_investment: resource, wide: @wide)
    end
  end

  def default_filter_options
    [
      ["newest", "Neueste zuerst"],
      ["oldest", "Zuerst die alten"],
    ]
  end
end
