class Subscriptions::EditComponent < ApplicationComponent
  attr_reader :user

  def initialize(user)
    @user = user
  end

  private

    def projekt_subscriptions
      @projekt_subscriptions ||= ProjektSubscription.active_for_user(user).to_a
    end

    def projekt_toggle_path
      ->(projekt) {
        update_projekt_subscriptions_path(projekt_id: projekt.id, token: user.subscriptions_token)
      }
    end
end
