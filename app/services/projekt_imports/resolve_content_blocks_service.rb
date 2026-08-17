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

    data["content_blocks"] = resolve_result.data[:blocks]
    projekt_import.update!(ai_result: data)

    ServiceResult.success(ai_result: data)
  rescue StandardError => e
    Rails.logger.error("[ProjektImports::ResolveContentBlocksService] failed: #{e.message}")
    Sentry.capture_exception(e, extra: { projekt_import_id: projekt_import.id, stage: "resolve_content_blocks" }) if defined?(Sentry)
    ServiceResult.failure(error: I18n.t("adm.projekts.imports.errors.resolve_content_blocks_failed", message: e.message))
  end

  private

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
