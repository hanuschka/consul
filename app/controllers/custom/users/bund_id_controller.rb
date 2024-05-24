class Users::BundIdController < ApplicationController
  skip_authorization_check
  skip_before_action :verify_authenticity_token, only: [:process_response]
  before_action :check_feature_flag

  def send_request
    request.headers["Turbolinks-Referrer"] = nil
    saml_redirect_request_url = BundIdServices::RedirectRequestMaker.call

    redirect_to(saml_redirect_request_url, allow_other_host: true)

    # @saml_post_request = CGI.escape(BundIdServices::PostRequestMaker.call)
    # @saml_second_post_request = BundIdServices::SecondPostRequestMaker.call
  end

  def process_response
    response = BundIdServices::ResponseProcessor.call(params[:SAMLResponse])
    debugger
    # response.success?
    response
  end

  private

    def check_feature_flag
      raise ActionController::RoutingError, "Not Found" unless Setting["feature.bund_id_login"]
    end
end
