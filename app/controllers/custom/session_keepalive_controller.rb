class SessionKeepaliveController < ApplicationController
  prepend_before_action :leave_session_untouched, only: :status
  before_action :authenticate_user!
  skip_authorization_check

  def ping
    head :ok
  end

  def status
    render json: { remaining_seconds: remaining_seconds }
  end

  private

    def leave_session_untouched
      request.env["devise.skip_timeout"] = true
      request.env["devise.skip_trackable"] = true
    end

    def remaining_seconds
      last_request_at = warden.session(:user)["last_request_at"]
      return User.timeout_in.to_i if last_request_at.blank?

      (Time.zone.at(last_request_at.to_i) + User.timeout_in - Time.current).to_i
    end
end
