class SiteCustomization::ContentBlocks::ChangeWithAiJob < ApplicationJob
  queue_as :default

  def perform(content_block_id)
    content_block = ::SiteCustomization::ContentBlock.unscoped.find_by(id: content_block_id)
    return if content_block.blank?

    options = (content_block.ai_generation_data || {})["options"] || {}

    content_block.mark_ai_generation_status!("processing")
    content_block.mark_ai_generation_step!("generating")

    result_html = edit(options)

    return if cancelled?(content_block)

    if result_html.blank?
      content_block.mark_ai_generation_status!(
        "failed",
        error: { message: I18n.t("ai.errors.generation_failed") }
      )
      return
    end

    content_block.mark_ai_generation_status!("completed", result_html: result_html)
  rescue => e
    Rails.logger.error(
      "SiteCustomization::ContentBlocks::ChangeWithAiJob failed: #{e.message}\n" \
      "#{e.backtrace.first(5).join("\n")}"
    )

    content_block&.mark_ai_generation_status!("failed", error: { message: e.message })
  end

  private

    def edit(options)
      ::Ai::EditContentBlock.call(
        options["instructions"],
        options["content_block_html"],
        options["title"],
        options["subtitle"],
        projekt: projekt_for(options),
        use_full_projekt_context: options["use_full_projekt_context"],
        allow_text_modification: options["allow_text_modification"],
        text_locale: options["text_locale"]
      )
    end

    def projekt_for(options)
      return if options["projekt_id"].blank?

      ::Projekt.find_by(id: options["projekt_id"])
    end

    # The editor can cancel while the generation is running, and that writes
    # straight to the row, so the in-memory copy cannot be trusted here.
    def cancelled?(content_block)
      fresh = ::SiteCustomization::ContentBlock.unscoped.find_by(id: content_block.id)

      fresh.present? && fresh.ai_generation_status == "cancelled"
    end
end
