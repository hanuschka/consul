class ProjektImports::ResolveContentBlocksService < ApplicationService
  attr_reader :projekt_import, :phases, :image_urls

  def initialize(projekt_import:, phases: [], image_urls: [])
    @projekt_import = projekt_import
    @phases = Array(phases)
    @image_urls = Array(image_urls)
  end

  def call
    data = projekt_import.ai_result
    return ServiceResult.success(ai_result: data) if data["content_blocks"].blank?

    resolve_result = ProjektImports::ResolveContentBlockHtmlService.call(
      blocks: data["content_blocks"],
      phase_links: build_phase_links,
      image_urls: image_urls,
      sentry_context: { projekt_import_id: projekt_import.id }
    )
    return resolve_result if !resolve_result.success?

    warn_about_missing_templates if !resolve_result.data[:templates_available]
    warn_about_unused_images(resolve_result.data[:unused_image_urls])

    data["content_blocks"] = resolve_result.data[:blocks]
    projekt_import.update!(ai_result: data)

    ServiceResult.success(ai_result: data)
  rescue StandardError => e
    Rails.logger.error("[ProjektImports::ResolveContentBlocksService] failed: #{e.message}")
    Sentry.capture_exception(e, extra: { projekt_import_id: projekt_import.id, stage: "resolve_content_blocks" }) if defined?(Sentry)
    ServiceResult.failure(error: I18n.t("adm.projekts.imports.errors.resolve_content_blocks_failed", message: e.message))
  end

  private

  # Every block falls back to escaped plain text when the template catalogue
  # cannot be reached, which looks like a styling bug rather than an outage
  # unless it is said out loud.
  def warn_about_missing_templates
    projekt_import.add_warning!(I18n.t("adm.projekts.imports.warnings.content_block_templates_unavailable"))
  end

  # The images are stored and reachable from the projekt's image gallery, so the
  # admin can place them by hand — but only if they are told the import did not.
  def warn_about_unused_images(unused_image_urls)
    count = Array(unused_image_urls).size
    return if count.zero?

    projekt_import.add_warning!(
      I18n.t("adm.projekts.imports.warnings.source_images_unplaced", count: count)
    )
  end

  # The phases already exist by the time blocks are rendered, so the model is
  # handed the real deep links instead of inventing a URL shape.
  def build_phase_links
    phases.each_with_index.map do |phase, index|
      {
        "phase_index" => index,
        "type" => phase.type,
        "name" => phase.title,
        "url" => phase.absolute_url
      }
    end
  end
end
