class Projekts::CrossInstanceImport::ImportJob < ApplicationJob
  queue_as :default

  def perform(projekt_id, source_url)
    projekt = Projekt.find_by(id: projekt_id)
    return if projekt.blank?

    bundle = fetch_bundle(source_url)

    # Without this the draft would sit in "processing" forever and the admin's
    # poller would spin until it gives up.
    if bundle.blank?
      Projekts::RecordCopyOutcome.call(
        projekt: projekt, error: "source instance returned no export for #{source_url}"
      )
      return
    end

    result = Projekts::CrossInstanceImport::ImportService.call(bundle: bundle, target: projekt)

    Projekts::RecordCopyOutcome.call(projekt: projekt, result: result)
  rescue StandardError => e
    Rails.logger.error("[Projekts::CrossInstanceImport::ImportJob] failed: #{e.class}: #{e.message}")

    if defined?(Sentry)
      Sentry.capture_exception(e, extra: { projekt_id: projekt_id })
    end

    Projekts::RecordCopyOutcome.call(projekt: projekt, error: e)
  end

  private

    # Fetched outside the transaction the import runs in: the round trip goes
    # through DT to another instance and back, and holding a write transaction
    # open across it would keep the projekt's rows locked for its duration.
    def fetch_bundle(source_url)
      response = DtApi::Client.new.projekt_exports.fetch(source_url)
      return nil if !response.success?

      response.parsed_response&.dig("export")
    end
end
