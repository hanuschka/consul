load Rails.root.join("app", "controllers", "moderation", "debates_controller.rb")

class Moderation::DebatesController < Moderation::BaseController
  has_filters %w[all unseen seen], only: :index
end
