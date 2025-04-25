class Shared::TextSearchFormComponent < ApplicationComponent
  attr_reader :i18n_namespace

  def initialize(i18n_namespace:, url: nil, remote: false, disable_reset_button_submit: false)
    @i18n_namespace = i18n_namespace
    @url = url
    @remote = remote
    @disable_reset_button_submit = disable_reset_button_submit
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
end
