class Adm::IndexTableComponent < ApplicationComponent
  include Pagy::Frontend

  renders_one :toolbar_meta
  renders_many :toolbar_actions
  renders_one :header_row
  renders_one :body

  attr_reader :turbo_frame_id, :records, :pagy, :headers, :column_count,
              :column_selector, :empty_state_config, :empty_state_filtered_config,
              :body_html_options

  def initialize(
    turbo_frame_id:,
    records:,
    headers:,
    column_count:,
    pagy: nil,
    column_selector: nil,
    empty_state:,
    empty_state_filtered: nil,
    body_html_options: {}
  )
    @turbo_frame_id = turbo_frame_id
    @records = records
    @pagy = pagy
    @headers = headers
    @column_count = column_count
    @column_selector = column_selector
    @empty_state_config = empty_state
    @empty_state_filtered_config = empty_state_filtered
    @body_html_options = body_html_options
  end

  def pills_component
    @pills_component ||= Adm::FilterPillsComponent.new(headers: headers.values, params: params)
  end

  def filters_active?
    pills_component.pills.any?
  end

  def column_selector?
    column_selector.present?
  end

  def show_toolbar?
    column_selector? || pills_component.render? || toolbar_meta? || toolbar_actions.any?
  end

  def show_pagination?
    pagy.present? && records.any? && pagy.pages > 1
  end

  def empty_state_for_current_view
    if filters_active? && empty_state_filtered_config.present?
      empty_state_filtered_config
    else
      empty_state_config
    end
  end
end
