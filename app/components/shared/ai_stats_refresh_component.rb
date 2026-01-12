class Shared::AiStatsRefreshComponent < ApplicationComponent
  attr_reader :resource, :refresh_path, :status_path

  def initialize(resource:, refresh_path:, status_path:)
    @resource = resource
    @refresh_path = refresh_path
    @status_path = status_path
  end

  def processing?
    resource.ai_stats_refresh_processing? || resource.ai_stats_refresh_pending?
  end

  def last_updated_at
    resource.ai_stats_refreshed_at
  end
end
