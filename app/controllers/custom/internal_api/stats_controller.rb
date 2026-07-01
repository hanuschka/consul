class InternalApi::StatsController < InternalApi::BaseController
  def show
    render json: {
      status:       "online",
      checked_at:   Time.current.iso8601,
      system_stats: Admin::SystemStatsService.call,
      app_metadata: Admin::AppMetadataService.call,
      features:     Admin::FeaturesService.call
    }
  end
end
