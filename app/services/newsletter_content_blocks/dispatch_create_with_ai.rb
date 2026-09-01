class NewsletterContentBlocks::DispatchCreateWithAi < ApplicationService
  attr_reader :newsletter, :placeholder

  def initialize(
    newsletter:,
    prompt:,
    mode: "add",
    category_hint: nil,
    anchor_template_id: nil,
    previous_content_block_id: nil,
    add_at_top: false,
    target_content_block_id: nil
  )
    @newsletter = newsletter
    @prompt = prompt
    @mode = mode.to_s
    @category_hint = category_hint
    @anchor_template_id = anchor_template_id
    @previous_content_block_id = previous_content_block_id
    @add_at_top = ActiveModel::Type::Boolean.new.cast(add_at_top)
    @target_content_block_id = target_content_block_id
  end

  def call
    if replace_mode?
      build_replace_placeholder
    else
      build_add_placeholder
    end

    return ServiceResult.failure(error: I18n.t("adm.newsletters.content_blocks.generate_with_ai.error")) if @placeholder.blank?

    NewsletterContentBlocks::CreateWithAiJob.perform_later(@placeholder.id, @mode)

    ServiceResult.success(content_block_id: @placeholder.id)
  end

  private

  def replace_mode?
    @mode == "replace"
  end

  def options_payload
    {
      "prompt" => @prompt,
      "category_hint" => @category_hint,
      "anchor_template_id" => @anchor_template_id,
      "text_locale" => I18n.locale.to_s
    }
  end

  def build_add_placeholder
    @placeholder = SiteCustomization::ContentBlock.unscoped.new(
      name: "custom",
      body: "",
      locale: SiteCustomization::ContentBlock.canonical_locale,
      newsletter_id: @newsletter.id,
      key: nil,
      position: nil,
      ai_generation_data: {
        "status" => "pending",
        "mode" => "add",
        "options" => options_payload,
        "insertion_context" => {
          "previous_content_block_id" => @previous_content_block_id,
          "add_at_top" => @add_at_top
        }
      }
    )

    @placeholder.save(validate: false)
  end

  def build_replace_placeholder
    target =
      SiteCustomization::ContentBlock
        .unscoped
        .where(newsletter_id: @newsletter.id)
        .find_by(id: @target_content_block_id)

    return if target.blank?

    target.update_columns(
      ai_generation_data: {
        "status" => "pending",
        "mode" => "replace",
        "options" => options_payload,
        "prior_body" => target.body.to_s
      }
    )

    @placeholder = target
  end
end
