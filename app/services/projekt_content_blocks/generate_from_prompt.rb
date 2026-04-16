class ProjektContentBlocks::GenerateFromPrompt < ApplicationService
  TASK_INSTRUCTIONS = <<~TEXT.freeze
    Generate structured HTML content blocks based on the user's description.
    Create appropriate HTML content blocks that represent the project described by the user.
    If dates are mentioned, extract them and include in your response as `projekt_start_date` and `projekt_end_date`, otherwise keep those fields empty.
  TEXT

  def initialize(projekt:)
    @projekt = projekt
    @generator = ProjektContentBlocks::AiGenerator.new(projekt: projekt)
  end

  def call
    prompt = @projekt.import_file_data&.dig("prompt")

    @generator.generate(
      task_instructions: TASK_INSTRUCTIONS,
      user_prompt: prompt
    )
  end
end
