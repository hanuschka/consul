load Rails.root.join("app", "controllers", "moderation", "proposals_controller.rb")

class Moderation::ProposalsController < Moderation::BaseController
  has_filters %w[unseen seen all], only: :index
end
