class ProjektContentBlocks::Services::DispatchChangeWithAi < ApplicationService
  attr_reader :content_block

  def initialize(
    content_block:,
    instructions:,
    content_block_html:,
    use_full_projekt_context: false,
    allow_text_modification: false
  )
    @content_block = content_block
    @instructions = instructions
    @content_block_html = content_block_html
    @use_full_projekt_context = ActiveModel::Type::Boolean.new.cast(use_full_projekt_context)
    @allow_text_modification = ActiveModel::Type::Boolean.new.cast(allow_text_modification)
  end

  def call
    @content_block.update_column(:ai_generation_data, {
      "status" => "pending",
      "step" => "queued",
      "mode" => "change",
      "options" => options_payload
    })

    Projekts::ChangeContentBlockWithAiJob.perform_later(@content_block.id)

    ServiceResult.success(content_block_id: @content_block.id)
  end

  private

  def options_payload
    {
      "instructions" => @instructions,
      "content_block_html" => @content_block_html,
      "use_full_projekt_context" => @use_full_projekt_context,
      "allow_text_modification" => @allow_text_modification,
      "text_locale" => I18n.locale.to_s
    }
  end
end
