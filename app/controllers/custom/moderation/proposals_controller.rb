require_dependency Rails.root.join("app", "controllers", "moderation", "proposals_controller").to_s

class Moderation::ProposalsController < Moderation::BaseController
  has_filters %w[unseen seen all], only: :index
end
