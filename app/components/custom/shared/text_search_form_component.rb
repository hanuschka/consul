class Shared::TextSearchFormComponent < ApplicationComponent
  attr_reader :i18n_namespace

  def initialize(i18n_namespace:, url: nil)
    @i18n_namespace = i18n_namespace
    @url = url
  end

  def remote_attribute
    @url.present?
  end

  def form_url
    @url.presence || ""
  end

  def other_query_params_from_current_path
    request.query_parameters&.except("utf8", "page", "search").presence || {}
  end
end
