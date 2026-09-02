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
    else
      content_block.destroy
    end
  end

  def handle_failure(content_block, mode, message)
    if mode.to_s == "replace"
      restore_prior_body(content_block, error_message: message)
    else
      content_block.mark_ai_generation_status!("failed", error: { message: message })
      content_block.destroy
    end
  end

  def restore_prior_body(content_block, error_message: nil)
    data = content_block.ai_generation_data || {}
    prior_body = data["prior_body"].to_s

    content_block.update_columns(
      body: prior_body,
      ai_generation_data: nil
    )
  end
end
