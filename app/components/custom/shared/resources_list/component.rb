class Shared::ResourcesList::Component < ApplicationComponent
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
      Projekts::ListItem::Component.new(projekt: resource, wide: @wide)
    when Proposal
      Proposals::ListItem::Component.new(proposal: resource, wide: @wide)
    when Debate
      Debates::ListItem::Component.new(debate: resource, wide: @wide)
    when Poll
      Polls::ListItem::Component.new(poll: resource, wide: @wide)
    end
  end
end
