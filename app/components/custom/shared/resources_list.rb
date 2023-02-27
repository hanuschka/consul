class Shared::ResourcesList < ApplicationComponent
  renders_one :bottom_content

  attr_reader :filters, :remote_url, :resource_type

  def initialize(
    title: nil,
    title_link: nil,
    resources:,
    resource_type: nil,
    resources_name: nil,
    filter_param: nil,
    filters: nil,
    current_filter: nil,
    filter_i18n_scope: nil,
    remote_url: nil,
    only_content: false,
    map_coordinates: nil,
    wide: false,
    css_class: nil,
    hide_title: false,
    filter_title: nil,
    no_items_text: nil,
    no_filter: false,
    additional_data: {}
  )
    @resources = resources
    @resource_type = resource_type
    @resources_name = resources.first.class.name.downcase.pluralize
    @title = title
    @title_link = title_link
    @wide = wide
    @filter_param = filter_param.presence || "order"
    # @filters = filters.presence || default_filter_options
    @filters = filters
    @current_filter = current_filter
    @filter_i18n_scope = filter_i18n_scope
    @remote_url = remote_url
    @only_content = only_content
    @map_coordinates = map_coordinates
    @css_class = css_class
    @hide_title = hide_title
    @no_items_text = no_items_text
    @filter_title = filter_title.presence || "Sortieren nach"
    @no_filter = no_filter
    @additional_data = additional_data
  end

  def class_names
    base = @css_class.to_s

    if @wide
      base += " -wide"
    end

    base
  end

  def selected_filter_otpion
    return if filters.blank?

    filters.find { |filter| filter == @current_filter }
  end

  def item_css_class
  end

  def i18n_namespace_for_filter
    if resource_type == Projekt
      "custom.projekts.orders"
    elsif resource_type == Debate
      "debates.index.orders"
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
      Budgets::Investments::ListItem.new(
        budget_investment: resource,
        ballot: @additional_data[:ballot],
        top_level_active_projekts: @additional_data[:top_level_active_projekts],
        top_level_archived_projekts: @additional_data[:top_level_archived_projekts],
        wide: @wide
      )
    when ProjektEvent
      ProjektEvents::ListItem.new(projekt_event: resource, wide: @wide)
    end
  end

  def default_filter_options
    [
      "newest",
      "oldest"
    ]
  end
end
