# frozen_string_literal: true

class Resources::List::ToolbarComponent < ApplicationComponent
  def initialize(
    i18n_namespace: nil,
    filters: nil,
    current_filter: nil,
    param: "filter",
    text_search_enabled: false,
    remote_url: nil,
    hide_view_mode_button: false,
    in_projekt_footer_tab: false
  )
    @i18n_namespace = i18n_namespace
    @filters = filters
    @current_filter = current_filter
    @param = param
    @text_search_enabled = text_search_enabled
    @remote_url = remote_url
    @hide_view_mode_button = hide_view_mode_button
    @in_projekt_footer_tab = in_projekt_footer_tab
  end

  def render?
    @text_search_enabled || @filters.present? || show_view_mode_button?
  end

  def show_view_mode_button?
    !@hide_view_mode_button
  end

  def filter_title
    if @param == "order"
      t("custom.shared.sort_by")
    elsif @param == "filter"
      t("custom.shared.filter_by")
    end
  end

  def selected_filter_option
    return if @filters.blank?

    @filters.find { |filter| filter == @current_filter }
  end

  def wide?
    helpers.cookies["wide_resources"] == "true"
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
end
