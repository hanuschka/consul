class Projekts::DispatchGenerateFromPrompt < ApplicationService
  attr_reader :projekt, :prompt

  def initialize(projekt:, prompt:)
    @projekt = projekt
    @prompt = prompt
  end

  def call
    projekt.update_columns(
      import_file_status: "pending",
      import_file_data: { prompt: prompt }
    )

    Projekts::GenerateContentFromPromptJob.perform_later(projekt.id)

    ServiceResult.success
  end
end
