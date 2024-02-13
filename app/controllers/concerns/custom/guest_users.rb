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
      @guest_user ||= create_guest_user
    end

    def create_guest_user
      User.new do |user|
        user.username = guest_key
        user.email = "#{guest_key}@example.com"
        user.guest = true
        user.current_sign_in_at = Time.current
        user.skip_confirmation!
        user.save!(validate: false)
      end
    end

    def guest_key
      session[:guest_user_id] ||= "guest_#{SecureRandom.uuid}"
    end
end
