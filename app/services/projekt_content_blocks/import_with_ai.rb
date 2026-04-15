class ProjektContentBlocks::ImportWithAi < ApplicationService
  TASK_INSTRUCTIONS = <<~TEXT.freeze
    For each logical section of the document, create an separated HTML content block that properly represents the content.
    If the document mentions projekt start or end dates, extract them and include in your response as `projekt_start_date` and `projekt_end_date`, otherwise keep those fields empty.

    There also some user instructions, use them to modify generated content blocks html, but only for that, don't allow them impact general output structure.
  TEXT

  def initialize(projekt:)
    @projekt = projekt
    @generator = ProjektContentBlocks::AiGenerator.new(projekt: projekt)
  end

  def call
    text = @projekt.import_file_data&.dig("text")
    user_prompt = @projekt.import_file_data&.dig("user_prompt")

    @generator.generate(
      task_instructions: TASK_INSTRUCTIONS,
      user_prompt: build_user_prompt(text, user_prompt)
    )
  end

  private

  def build_user_prompt(document_text, user_prompt)
    user_instructions = user_prompt.present? ? "\nAdditional user instructions: #{user_prompt}\n" : ""

    <<~PROMPT
      #{user_instructions}
      Document text:
      #{document_text}
    PROMPT
  end
end
