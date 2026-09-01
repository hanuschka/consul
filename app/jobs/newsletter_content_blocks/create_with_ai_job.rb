class NewsletterContentBlocks::CreateWithAiJob < ApplicationJob
  queue_as :default

  def perform(content_block_id, mode)
    content_block = SiteCustomization::ContentBlock.unscoped.find_by(id: content_block_id)
    return if content_block.blank?

    newsletter = content_block.newsletter
    return if newsletter.blank?

    data = content_block.ai_generation_data || {}
    options = data["options"] || {}

    Ai::GenerateContentBlock.call(
      content_block: content_block,
      projekt: nil,
      newsletter: newsletter,
      dt_template_section: "newsletter_email",
      prompt: options["prompt"],
      category_hint: options["category_hint"],
      anchor_template_id: options["anchor_template_id"],
      text_locale: options["text_locale"]
    )
  rescue Ai::GenerateContentBlock::AiCancelledError
    handle_cancellation(content_block, mode)
  rescue => e
    Rails.logger.error("NewsletterContentBlocks::CreateWithAiJob failed: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
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
      restore_prior_body(content_block)
    else
      content_block.mark_ai_generation_status!("failed", error: { message: message })
    end
  end

  def restore_prior_body(content_block)
    data = content_block.ai_generation_data || {}
    prior_body = data["prior_body"].to_s

    content_block.update_columns(
      body: prior_body,
      ai_generation_data: nil
    )
  end
end
