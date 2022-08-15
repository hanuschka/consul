class ProjektManagement::ProposalsController < ProjektManagement::BaseController
  include ModerateActions
  include FeatureFlags

  has_filters %w[all unseen seen], only: :index
  has_orders %w[flags created_at], only: :index

  feature_flag :proposals

  before_action :load_resources, only: [:index, :moderate]

  load_and_authorize_resource

  def index
    super

    render "moderation/proposals/index"
  end

  private

    def resource_model
      Proposal
    end
end
