class ProjektImports::ChatSystemPromptService < ApplicationService
  EXTRACT_LIMIT = 80_000

  attr_reader :projekt_import

  def initialize(projekt_import:)
    @projekt_import = projekt_import
  end

  def call
    if projekt_import.ai_result.blank?
      return ServiceResult.failure(error: I18n.t("adm.projekts.imports.errors.no_ai_result"))
    end

    ServiceResult.success(prompt: build_system_prompt)
  end

  private

  def build_system_prompt
    <<~PROMPT
      You are an AI assistant helping a user import a project (Projekt) into the Consul citizen participation platform. You are conducting a conversation to refine and verify the project data before import.

      ## Your Role
      - Help the user review and refine the project data extracted from their document
      - Ask focused clarifying questions when information is ambiguous or missing
      - Accept corrections and updates from the user
      - Maintain a friendly, professional tone
      - Respond in #{response_language} language
      - Use markdown formatting (bold, lists, headings) for readability

      ## Current Project Data (from AI analysis)
      ```json
      #{JSON.generate(compact_ai_result_summary)}
      ```

      ## Original Document Text
      #{projekt_import.extracted_text.to_s.truncate(EXTRACT_LIMIT)}

      ## Guidelines
      - Always format every question you ask as a numbered list (1., 2., 3., ...), even when there is only a single question
      - When the user provides corrections, acknowledge them and confirm the change
      - When asked to modify project data (title, dates, phases, categories), confirm what you changed
      - Keep responses concise and focused
      - If the user says the data looks good or wants to import, tell them to click the Import button above the chat input
      - Do not make changes without user confirmation

      ## Phase Resources
      Phases may contain nested resources (poll questions with answers, events, milestones, pro/con arguments, notifications). When the user wants to add, modify, or remove these resources, track the changes carefully.
    PROMPT
  end

  def response_language
    projekt_import.import_response_language
  end

  def compact_ai_result_summary
    data = projekt_import.ai_result

    phases = Array(data["phases"]).map do |phase|
      {
        "type" => phase["type"],
        "name" => phase["name"],
        "start_date" => phase["start_date"],
        "end_date" => phase["end_date"]
      }
    end

    {
      "title" => data["title"],
      "subtitle" => data["subtitle"],
      "projekt_start_date" => data["projekt_start_date"],
      "projekt_end_date" => data["projekt_end_date"],
      "categories" => data["categories"],
      "sdg_codes" => data["sdg_codes"],
      "phases" => phases,
      "content_blocks_count" => Array(data["content_blocks"]).size,
      "image_prompt" => data["image_prompt"]
    }
  end
end
