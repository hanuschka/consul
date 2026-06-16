class MasterportalDestroyAllPinsJob < ApplicationJob
  queue_as :default

  def perform(projekt_phase_id:)
    projekt_phase = ProjektPhase.find(projekt_phase_id)

    Masterportal::DestroyAllPinsService.call(projekt_phase: projekt_phase)
  end
end
