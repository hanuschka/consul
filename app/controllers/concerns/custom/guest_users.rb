module GuestUsers
  extend ActiveSupport::Concern

  included do
    before_action :current_user
  end

  def current_user
    super || guest_user
  end

  def user_signed_in?
    current_user && !current_user.guest?
  end

  private

    def guest_user
      return @guest_user if @guest_user

      if session[:guest_user_id]
        @guest_user = User.find_by(username: session[:guest_user_id], guest: true)
      end
    end
end
