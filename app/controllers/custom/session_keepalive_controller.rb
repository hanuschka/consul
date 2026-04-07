class SessionKeepaliveController < ApplicationController
  before_action :authenticate_user!
  skip_authorization_check

  def ping
    head :ok
  end
end
