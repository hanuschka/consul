class ProjektPhase::Stats
  include Statisticable
  alias_method :projekt_phase, :resource

  private

    def stats_cache(key, &block)
      Rails.cache.fetch("projekt_phase_stats/#{projekt_phase.id}/#{key}/#{version}", &block)
    end
end
