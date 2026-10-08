class Projekts::CopyJob < ApplicationJob
  queue_as :default

  def perform(source_projekt_id, copy_projekt_id)
    copy = Projekt.find_by(id: copy_projekt_id)
    return if copy.blank?

    source = Projekt.find_by(id: source_projekt_id)

    # Without this the copy would sit in "processing" forever and the admin's
    # poller would spin until it gives up.
    if source.blank?
      Projekts::RecordCopyOutcome.call(projekt: copy, error: "source projekt no longer exists")
      return
    end

    result = Projekts::CopyService.call(source: source, copy: copy)

    Projekts::RecordCopyOutcome.call(projekt: copy, result: result)
  rescue StandardError => e
    Rails.logger.error("[Projekts::CopyJob] failed: #{e.class}: #{e.message}")

    if defined?(Sentry)
      Sentry.capture_exception(e, extra: { copy_projekt_id: copy_projekt_id })
    end

    Projekts::RecordCopyOutcome.call(projekt: copy, error: e)
  end
end
