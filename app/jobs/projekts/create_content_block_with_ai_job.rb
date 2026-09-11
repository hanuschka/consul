class Projekts::CreateContentBlockWithAiJob < ApplicationJob
  queue_as :default

  def perform(content_block_id, mode)
    content_block = SiteCustomization::ContentBlock.unscoped.find_by(id: content_block_id)
    return if content_block.blank?

    projekt = content_block.projekt
    return if projekt.blank? && mode.to_s != "replace"

    data = content_block.ai_generation_data || {}
    options = data["options"] || {}

    Ai::GenerateContentBlock.call(
      content_block: content_block,
      projekt: projekt,
      prompt: options["prompt"],
      category_hint: options["category_hint"],
      anchor_template_id: options["anchor_template_id"],
      use_projekt_context: options["use_projekt_context"],
      text_locale: options["text_locale"]
    )
  rescue Ai::GenerateContentBlock::AiCancelledError
    handle_cancellation(content_block, mode)
  rescue => e
    Rails.logger.error("CreateContentBlockWithAiJob failed: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
    handle_failure(content_block, mode, e.message)
  end

  private

  def handle_cancellation(content_block, mode)
    if mode.to_s == "replace"
      restore_prior_body(content_block)
      content_block.mark_ai_generation_status!("cancelled")
    else
      content_block.destroy
    end
  end

  # The row survives a failure so the poller can read the error off it. Add-mode
  # placeholders stay hidden by the default scope until the next dispatch purges
  # them; destroying one here raced the 3s poll and lost the message with it.
  def handle_failure(content_block, mode, message)
    restore_prior_body(content_block) if mode.to_s == "replace"

    content_block.mark_ai_generation_status!("failed", error: { message: message })
  end

  def restore_prior_body(content_block)
    data = content_block.ai_generation_data || {}

    content_block.update_columns(body: data["prior_body"].to_s)
  end
end
