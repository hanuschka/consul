class DocsController < ApplicationController
  skip_authorization_check

  before_action :set_spec_url, only: [:api, :api_alt]

  def api
    respond_to do |format|
      format.html { render :api, layout: false }
    end
  end

  def api_alt
    respond_to do |format|
      format.html { render :api_alt, layout: false }
    end
  end

  private

  def set_spec_url
    @spec_url = '/api_docs/v1/swagger.yaml'
  end
end
