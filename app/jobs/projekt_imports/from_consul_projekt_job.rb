class ProjektImports::FromConsulProjektJob < ApplicationJob
  queue_as :projekt_imports

  BUNDLE_FILENAME = "projekt_export.json".freeze

  def perform(projekt_import_id)
    projekt_import = ProjektImport.find(projekt_import_id)
    projekt_import.update!(status: "extracting")

    fetch_result = ProjektImports::FetchConsulBundleService.call(
      source_url: projekt_import.source_url
    )

    if !fetch_result.success?
      projekt_import.mark_failed!(
        fetch_result.error, stage: "fetch_bundle", details: fetch_result.error_details
      )
      return
    end

    bundle = fetch_result.data[:bundle]
    projekt_import.update!(status: "processing", content_locale: ProjektImport.default_content_locale)

    attach_bundle(projekt_import, bundle)

    overlay_result = ProjektImports::BuildBundleOverlayService.call(
      bundle: bundle, locale: projekt_import.import_locale
    )

    projekt_import.update!(source_overlay: overlay_result.data[:overlay], status: "chatting")
  rescue StandardError => e
    Rails.logger.error("[ProjektImports::FromConsulProjektJob] failed: #{e.message}")
    Sentry.capture_exception(e, extra: { projekt_import_id: projekt_import_id, stage: "from_consul_projekt_job" }) if defined?(Sentry)
    pi = ProjektImport.find_by(id: projekt_import_id)
    pi&.mark_failed!(e.message, exception: e)
    raise
  end

  private

    # Stored once here rather than fetched again at execute time: the review
    # step can take a while, and a projekt built from a second fetch would not
    # be the one the admin was shown.
    def attach_bundle(projekt_import, bundle)
      projekt_import.source_bundle.attach(
        io: StringIO.new(bundle.to_json),
        filename: BUNDLE_FILENAME,
        content_type: "application/json"
      )
    end
end
