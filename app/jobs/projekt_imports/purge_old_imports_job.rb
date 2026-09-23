class ProjektImports::PurgeOldImportsJob < ApplicationJob
  queue_as :projekt_imports

  COMPLETED_TTL = 30.days
  FAILED_TTL = 7.days

  # An import that is neither finished nor failed is one nobody came back to:
  # a chat left open, or an analysis whose worker died long before the 15
  # minutes ANALYSIS_STALL_AFTER already calls stalled. It holds on to whatever
  # the source step gathered — uploaded documents, or a whole serialized
  # projekt for a Consul import — so it cannot be left sitting forever.
  STALE_TTL = 14.days

  def perform
    abandon_stale_imports

    ProjektImport.where(status: "completed").where("updated_at < ?", COMPLETED_TTL.ago).find_each(&:destroy)
    ProjektImport.where(status: %w[failed abandoned]).where("updated_at < ?", FAILED_TTL.ago).find_each(&:destroy)
  end

  private

    # Marked rather than destroyed, so a forgotten import first becomes visibly
    # abandoned and only the next sweep past FAILED_TTL removes it. That leaves
    # a week in which an admin who does come back still finds the row and its
    # error, instead of the import vanishing on the day it went stale.
    #
    # update_all rather than mark_abandoned!: no callback needs to run, and a
    # single row failing a validation must not stop the sweep. updated_at is
    # written explicitly because update_all does not touch it, and it is what
    # starts the FAILED_TTL countdown.
    def abandon_stale_imports
      ProjektImport
        .in_progress
        .where("updated_at < ?", STALE_TTL.ago)
        .update_all(status: "abandoned", updated_at: Time.current)
    end
end
