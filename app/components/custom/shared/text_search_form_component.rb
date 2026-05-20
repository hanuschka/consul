class Shared::TextSearchFormComponent < ApplicationComponent
  attr_reader :i18n_namespace, :input_extra_class, :input_id

  def initialize(
    i18n_namespace:,
    url: nil,
    remote: false,
    disable_reset_button_submit: false,
    standalone: false,
    input_extra_class: nil,
    input_id: "search_text"
  )
    @i18n_namespace = i18n_namespace
    @url = url
    @remote = remote
    @disable_reset_button_submit = disable_reset_button_submit
    @standalone = standalone
    @input_extra_class = input_extra_class
    @input_id = input_id
  end

  def standalone?
    @standalone
  end

  def disable_reset_button_submit?
    @disable_reset_button_submit
  end

  def remote_attribute
    @remote
  end

  def form_url
    @url.presence || ""
  end

  def other_query_params_from_current_path
    request.query_parameters&.except("utf8", "page", "search").presence || {}
  end

  def input_classes
    ["input-group-field", "js-text-search-form-search-input", input_extra_class].compact.join(" ")
  end
end
