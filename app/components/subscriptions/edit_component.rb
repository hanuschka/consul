class Subscriptions::EditComponent < ApplicationComponent
  attr_reader :user

  def initialize(user)
    @user = user
  end

  private

    def projekt_subscriptions
      user.projekt_subscriptions
        .joins(projekt: :page)
        .includes(projekt: :page)
        .order("projekts.name")
    end
end
