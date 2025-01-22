class ProjektManagement::DebatesController < ProjektManagement::BaseController
  include ModerateActions
  include FeatureFlags

  has_filters %w[all unseen seen], only: :index
  has_orders %w[flags created_at], only: :index

  feature_flag :debates

  before_action :load_resources, only: [:index, :moderate]

  load_and_authorize_resource

  def index
    super

    respond_to do |format|
      format.html do
        render "moderation/debates/index"
      end

      format.csv do
        send_data CsvServices::DebatesExporter.call(@resources.limit(nil)),
          filename: "debates-#{Time.current.strftime("%d-%m-%Y-%H-%M-%S")}.csv"
      end
    end
  end

  private

    def resource_model
      Debate
    end
end
