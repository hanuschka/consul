class Projekts::ChangeContentBlockWithAiJob < ApplicationJob
  queue_as :default

  # The edited HTML is handed back to the editor as a preview rather than
  # written to the block: the editor applies it to the DOM and the author
  # saves it through the normal update path, exactly as the inline call did.
  def perform(content_block_id)
    content_block = SiteCustomization::ContentBlock.unscoped.find_by(id: content_block_id)
    return if content_block.blank?

    options = (content_block.ai_generation_data || {})["options"] || {}
    projekt = content_block.projekt

    content_block.mark_ai_generation_status!("processing")
    content_block.mark_ai_generation_step!("generating")

    result_html = Ai::EditContentBlock.call(
      options["instructions"],
      options["content_block_html"],
      projekt&.page&.title,
      projekt&.page&.subtitle,
      projekt: projekt,
      use_full_projekt_context: options["use_full_projekt_context"],
      allow_text_modification: options["allow_text_modification"],
      text_locale: options["text_locale"]
    )

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
      "ChangeContentBlockWithAiJob failed: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    )

    content_block&.mark_ai_generation_status!("failed", error: { message: e.message })
  end

  private

  def cancelled?(content_block)
    fresh = SiteCustomization::ContentBlock.unscoped.find_by(id: content_block.id)

    fresh.present? && fresh.ai_generation_status == "cancelled"
  end
end
