class Users::BundIdController < ApplicationController
  skip_authorization_check

  def send_request
    request.headers["Turbolinks-Referrer"] = nil
    saml_redirect_request = BundIdServices::RedirectRequestMaker.call
    redirect_to("https://int.id.bund.de/idp/profile/SAML2/Redirect/SSO?SAMLRequest=#{saml_redirect_request}", allow_other_host: true)

    # @saml_post_request = CGI.escape(BundIdServices::PostRequestMaker.call)
    # @saml_second_post_request = BundIdServices::SecondPostRequestMaker.call
  end
end
