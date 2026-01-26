class DocsController < ApplicationController
  skip_authorization_check

  before_action :set_spec_url, only: [:api, :api_alt]

  def api
    render :api, layout: false
  end

  def api_alt
    render :api_alt, layout: false
  end

  private

  def set_spec_url
    @spec_url = '/api_docs/v1/swagger.yaml'
  end
end
