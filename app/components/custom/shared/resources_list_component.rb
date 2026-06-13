# frozen_string_literal: true

class Shared::ResourcesListComponent < ApplicationComponent
  renders_one :bottom_content
  renders_one :custom_body
  renders_one :items_remark

  attr_reader :filters, :remote_url, :resource_type, :resources

  def initialize(
    resources: nil,
    resource_type: nil,
    title: nil,
    filters: nil,
    current_filter: nil,
    filter_param: "filter",
    remote_url: nil,
    filter_i18n_namespace: nil,
    only_content: false,
    text_search_enabled: false,
    hide_view_mode_button: false,
    projekt_phase: nil,
    additional_data: {}
  )
    @resources = resources
    @resource_type = resource_type
    @title = title
    @filters = filters
    @current_filter = current_filter
    @remote_url = remote_url
    @only_content = only_content
    @text_search_enabled = text_search_enabled
    @filter_i18n_namespace = filter_i18n_namespace
    @filter_param = filter_param
    @hide_view_mode_button = hide_view_mode_button
    @projekt_phase = projekt_phase
    @additional_data = additional_data
  end

  def filter_title
    if @filter_param == "order"
      t("custom.shared.sort_by")
    elsif @filter_param == "filter"
      t("custom.shared.filter_by")
    end
  end

  def wide?
    helpers.cookies["wide_resources"] == "true"
  end

  def class_names
    wide? ? "-wide" : ""
  end

  def selected_filter_option
    return if filters.blank?

    filters.find { |filter| filter == @current_filter }
  end

  def i18n_namespace
    return @filter_i18n_namespace if @filter_i18n_namespace.present?

    resource_types.dig(resource_type, :i18n_namespace)
  end

  def empty_list_text
    t("empty_list_text", scope: i18n_namespace)
  end

  def switch_view_mode_icon
    wide? ? "fa-grip-vertical" : "fa-bars"
  end

  def switch_view_mode_label
    if wide?
      t("custom.accessibility.shared.switch-view-button.to-list")
    else
      t("custom.accessibility.shared.switch-view-button.to-tile")
    end
  end

  def resource_component(resource)
    match = resource_types.find { |klass, _| resource.is_a?(klass) }
    return if match.blank?

    context = { resources: resources, additional_data: @additional_data }

    match.last[:component].call(resource, context)
  end

  private

  def resource_types
    @resource_types ||= {
      Projekt => {
        i18n_namespace: "custom.projekts",
        component: ->(resource, _) { Projekts::ListItemComponent.new(projekt: resource) }
      },
      Proposal => {
        i18n_namespace: "custom.proposals.index",
        component: ->(resource, _) { Proposals::ListItemComponent.new(proposal: resource) }
      },
      Debate => {
        i18n_namespace: "custom.debates.index",
        component: ->(resource, _) { Debates::ListItemComponent.new(debate: resource) }
      },
      Poll => {
        i18n_namespace: "custom.polls.index",
        component: ->(resource, _) { Polls::ListItemComponent.new(poll: resource) }
      },
      DeficiencyReport => {
        i18n_namespace: "custom.deficiency_reports.index",
        component: ->(resource, _) { DeficiencyReports::ListItemComponent.new(deficiency_report: resource) }
      },
      Budget::Investment => {
        i18n_namespace: "custom.budgets.investments.index",
        component: ->(resource, context) {
          Budgets::Investments::ListItemComponent.new(
            budget_investment: resource,
            budget_investment_ids: context[:resources].pluck(:id),
            ballot: context[:additional_data][:ballot]
          )
        }
      },
      Idea => {
        i18n_namespace: "custom.ideas.index",
        component: ->(resource, _) { Ideas::ListItemComponent.new(idea: resource) }
      },
      Topic => {
        i18n_namespace: "custom.topics.list",
        component: ->(resource, _) { Topics::ListItemComponent.new(topic: resource) }
      },
      ProjektEvent => {
        i18n_namespace: nil,
        component: ->(resource, _) { Projekts::ProjektEvents::ListItemComponent.new(projekt_event: resource) }
      }
    }
  end
end
