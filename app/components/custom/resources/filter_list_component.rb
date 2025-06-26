class Resources::FilterListComponent < ApplicationComponent
  renders_one :top_section
  renders_one :items
  renders_one :no_items_message
  renders_one :bottom_content

  attr_reader :filters, :remote_url

  def initialize(
    title: nil,
    filters: nil,
    current_filter: nil,
    filter_param: "filter",
    remote_url: nil,
    filter_i18n_namespace: nil,
    text_search_enabled: false,
    hide_view_mode_button: false,
    in_projekt_footer_tab: false,
    anchor: nil
  )
    @title = title
    @filters = filters
    @current_filter = current_filter
    @filter_param = filter_param
    @filter_i18n_namespace = filter_i18n_namespace
    @remote_url = remote_url
    @text_search_enabled = text_search_enabled
    @hide_view_mode_button = hide_view_mode_button
    @in_projekt_footer_tab = in_projekt_footer_tab
    @anchor = anchor
  end

  def filter_title
    if @filter_param == "order"
      t("custom.shared.sort_by")
    elsif @filter_param == "filter"
      t("custom.shared.filter_by")
    end
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

  def selected_filter_option
    return if filters.blank?

    filters.find { |filter| filter == @current_filter }
  end

  def i18n_namespace
    "#{@filter_i18n_namespace}.#{@filter_param&.pluralize || "filters"}"
  end

  def switch_view_mode_icon
    wide? ? "fa-grip-vertical" : "fa-bars"
  end

  def default_filter_options
    [
      "newest",
      "oldest"
    ]
  end

  def hide_list_line_divider?
    resource_type == Topic
  end

  def selected_option
    translate_option(selected_filter_option.presence || @filters.first)
  end

  def remote?
    remote_url.present?
  end

  def translate_option(option)
    return if option.blank?

    t("#{i18n_namespace}.#{option}")
  end

  def link_path(option)
    if helpers.params[:projekt_phase_id].present?
      link_options = {}
      link_options[@filter_param.to_sym] = option
      link_options[:remote] = true
      url_to_footer_tab(**link_options)

    elsif remote_url.present?
      url = "#{remote_url}?#{@url_param_name}=#{option}"

      if anchor.present?
        url = "#{url}#?#{anchor}"
      end

      url
    else
      params = {}
      params[@url_param_name] = option
      current_path_with_query_params(anchor: anchor, **params, page: nil)
    end
  end

  def footer_tab_back_button_url(option)
    if params[:projekt_phase_id].present?
      url_to_footer_tab(**[[@url_param_name, option]].to_h.symbolize_keys)
    end
  end

  def link_data_attributes(option)
    data = {}

    if remote?
      data["nonblock-remote"] = "true"
      data["remote"] = "true"
    end

    if @in_projekt_footer_tab
      data["footer-tab-back-url"] = footer_tab_back_button_url(option)
    end

    data
  end

  def link_class
    return unless remote?

    "js-remote-link-push-state" if @in_projekt_footer_tab
  end

  def onclick
    return unless remote?

    if @in_projekt_footer_tab
      "$('#footer-content').addClass('show-loader');"
    else
      "$('.main-column').addClass('show-loader');"
    end
  end
end
