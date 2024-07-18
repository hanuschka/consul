module IframeEmbeddedBehavior
  extend ActiveSupport::Concern

  included do
    before_action :set_iframe_content_security_policy
    helper_method :embedded?
  end

  private

    def set_iframe_content_security_policy
      response.headers["Content-Security-Policy"] =
        "frame-ancestors #{Rails.application.secrets.dt[:url]}"
    end

    def embedded?
      @embedded ||=
        (params[:embedded] == "true")
    end
end
