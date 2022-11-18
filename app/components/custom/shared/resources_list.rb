class Shared::ResourcesList < ApplicationComponent
  renders_one :body

  def initialize(resources:, title:, wide: false)
    @resources = resources
    @title = title
    @wide = wide
  end

  def class_names
    if @wide
      "-wide"
    end
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
    end
  end
end
