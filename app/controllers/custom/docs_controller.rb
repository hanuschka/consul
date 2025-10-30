class DocsController < ApplicationController
  skip_authorization_check

  def api
    render :api, layout: false
  end
end
