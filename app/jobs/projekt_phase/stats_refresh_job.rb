class ProjektPhase::StatsRefreshJob < ApplicationJob
  queue_as :default

  STATS_SERVICES = {
    ProjektPhase::ProposalPhase => ProjektPhase::ProposalPhase::StatsService
  }.freeze

  def perform(projekt_phase_id)
    projekt_phase = ProjektPhase.find_by(id: projekt_phase_id)
    return unless projekt_phase

    service_class = STATS_SERVICES[projekt_phase.class]
    return unless service_class

    service_class.new(projekt_phase).call
  end
end
