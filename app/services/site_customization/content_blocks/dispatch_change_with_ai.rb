# Editing a block with AI is the same operation whichever surface owns the
# block — projekt page, newsletter or site customization. Nothing is written to
# the block: the generated HTML is a preview the editor applies and the author
# saves through the normal update path. So the owner only contributes the
# heading context the prompt gets, carried here as plain options.
class SiteCustomization::ContentBlocks::DispatchChangeWithAi < ApplicationService
  attr_reader :content_block

  def initialize(
    content_block:,
    instructions:,
    content_block_html:,
    title: nil,
    subtitle: nil,
    projekt: nil,
    use_full_projekt_context: false,
    allow_text_modification: false
  )
    @content_block = content_block
    @instructions = instructions
    @content_block_html = content_block_html
    @title = title
    @subtitle = subtitle
    @projekt = projekt
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

    ::SiteCustomization::ContentBlocks::ChangeWithAiJob.perform_later(@content_block.id)

    ServiceResult.success(content_block_id: @content_block.id)
  end

  private

    def options_payload
      {
        "instructions" => @instructions,
        "content_block_html" => @content_block_html,
        "title" => @title,
        "subtitle" => @subtitle,
        "projekt_id" => @projekt&.id,
        "use_full_projekt_context" => @use_full_projekt_context,
        "allow_text_modification" => @allow_text_modification,
        "text_locale" => I18n.locale.to_s
      }
    end
end
