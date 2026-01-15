class Shared::StatsRefreshComponent < ApplicationComponent
  attr_reader :resource, :refresh_path, :status_path, :section

  def initialize(resource:, refresh_path:, status_path:, section: nil)
    @resource = resource
    @refresh_path = refresh_path
    @status_path = status_path
    @section = section
  end

  def processing?
    resource.ai_stats_refresh_processing? || resource.ai_stats_refresh_pending?
  end

  def last_updated_at
    resource.ai_stats_refreshed_at
  end
end
