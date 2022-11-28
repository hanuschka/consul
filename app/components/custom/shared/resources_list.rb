class Shared::ResourcesList < ApplicationComponent
  renders_one :additional_top_content
  renders_one :body

  def initialize(resources:, filter_param: nil, filter_options: nil, title:, wide: false)
    @resources = resources
    @title = title
    @wide = wide
    @filter_param = filter_param.presence || "created_at"
    @filter_options = filter_options.presence || default_filter_options
  end

  def class_names
    if @wide
      "-wide"
    end
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
      ["desc", "Neueste zuerst"],
      ["asc", "Zuerst die alten"],
      ["asc", "Zuerst die alten"],
      ["asc", "Zuerst die alten"]
    ]
  end
end
