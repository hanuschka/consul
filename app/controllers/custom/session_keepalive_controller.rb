class SessionKeepaliveController < ApplicationController
  before_action :authenticate_user!

  def ping
    head :ok
  end
end
