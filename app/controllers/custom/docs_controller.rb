class DocsController < ApplicationController
  skip_authorization_check

  def api
    render :api, layout: false
  end

  def api_alt
    render :api_alt, layout: false
  end
end
