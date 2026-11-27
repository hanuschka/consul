class Projekts::SubscriptionListComponent < ApplicationComponent
  def initialize(subscriptions:, toggle_path:)
    @subscriptions = subscriptions
    @toggle_path = toggle_path
  end
end
