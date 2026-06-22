class ProjektImports::FinalizeDataService < ApplicationService
  RETRY_INSTRUCTION = "Your previous response was not valid JSON matching the schema. Please respond again with ONLY a JSON object matching the schema."

  attr_reader :projekt_import

  def initialize(projekt_import:)
    @projekt_import = projekt_import
  end

  def call
    return ServiceResult.success(ai_result: projekt_import.ai_result) if !user_chat_messages?

    refs = ProjektImports::ReferencesBuilder.build
    schema = ProjektImports::OutputSchemaBuilder.build(refs)
    system_prompt = build_system_prompt
    user_instruction = finalization_instruction

    updated_data = call_with_retry(system_prompt: system_prompt, schema: schema, user_instruction: user_instruction)

    if updated_data.blank?
      return ServiceResult.failure(error: I18n.t("adm.projekts.imports.errors.ai_malformed"))
    end

    projekt_import.update!(ai_result: updated_data)

    ServiceResult.success(ai_result: updated_data)
  rescue StandardError => e
    Rails.logger.error("[ProjektImports::FinalizeDataService] failed: #{e.message}")
    ServiceResult.failure(error: I18n.t("adm.projekts.imports.errors.finalize_failed", message: e.message))
  end

  private

  def user_chat_messages?
    ai_chat = projekt_import.ai_chat
    return false if ai_chat.blank?

    ai_chat.ai_chat_messages.where(role: "user").exists?
  end

  def build_system_prompt
    <<~PROMPT
      You are an AI assistant that has been reviewing project import data with a user.
      Your task is to track all modifications requested during the conversation.

      Original project data (from initial AI analysis):
      ```json
      #{JSON.generate(projekt_import.ai_result)}
      ```
    PROMPT
  end

  def finalization_instruction
    <<~PROMPT
      Based on our entire conversation, return the COMPLETE updated project data as a single JSON object.
      Apply ALL modifications requested during our chat to the original data.
      Use the EXACT same JSON structure and field names as the original data shown in the system prompt.
      If a field was not discussed, keep its original value unchanged.
      IMPORTANT: Preserve the exact order of elements in all arrays, especially content_blocks.
      Return ONLY the JSON object with no additional text or explanation.
    PROMPT
  end

  def call_with_retry(system_prompt:, schema:, user_instruction:)
    response = call_ai(system_prompt: system_prompt, schema: schema, user_instruction: user_instruction)
    return response if response.is_a?(Hash) && response.present?

    Rails.logger.warn("[ProjektImports::FinalizeDataService] first attempt failed, retrying")

    call_ai(
      system_prompt: "#{system_prompt}\n\n#{RETRY_INSTRUCTION}",
      schema: schema,
      user_instruction: user_instruction
    )
  end

  def call_ai(system_prompt:, schema:, user_instruction:)
    chat = Ai::RubyLlmFactory.chat_with_json_output(schema).with_instructions(system_prompt)

    projekt_import
      .ai_chat
      .ai_chat_messages
      .where.not(content: [nil, ""])
      .order(created_at: :asc)
      .each do |msg|
        chat.add_message(role: msg.role.to_sym, content: msg.content)
      end

    response = chat.ask(user_instruction)
    response.content
  rescue StandardError => e
    Rails.logger.error("[ProjektImports::FinalizeDataService] AI call error: #{e.message}")
    nil
  end
end
