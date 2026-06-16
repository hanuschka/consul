class ProjektImports::PurgeOldImportsJob < ApplicationJob
  queue_as :projekt_imports

  COMPLETED_TTL = 30.days
  FAILED_TTL = 7.days

  def perform
    ProjektImport.where(status: "completed").where("updated_at < ?", COMPLETED_TTL.ago).find_each(&:destroy)
    ProjektImport.where(status: %w[failed abandoned]).where("updated_at < ?", FAILED_TTL.ago).find_each(&:destroy)
  end
end
