class ProjektImports::ChatResponseService < ApplicationService
  attr_reader :projekt_import, :assistant_message

  def initialize(projekt_import:, assistant_message:)
    @projekt_import = projekt_import
    @assistant_message = assistant_message
  end

  def call
    prompt_result = ProjektImports::ChatSystemPromptService.call(projekt_import: projekt_import)
    return prompt_result if !prompt_result.success?

    chat = Ai::RubyLlmFactory.chat(feature: "projekt_imports.chat_response")
      .with_instructions(prompt_result.data[:prompt])
    chat.with_tools(*edit_tools)
    history = build_history

    history[0..-2].each do |msg|
      if msg[:role] == "user"
        chat.add_message(role: :user, content: msg[:content])
      else
        chat.add_message(role: :assistant, content: msg[:content])
      end
    end

    last_user = history.last
    response = chat.ask(last_user[:content])
    text = extract_text(response)

    if text.blank?
      return ServiceResult.failure(error: I18n.t("adm.projekts.imports.errors.ai_empty_response"))
    end

    ServiceResult.success(content: text)
  rescue StandardError => e
    Rails.logger.error("[ProjektImports::ChatResponseService] failed: #{e.message}")
    Sentry.capture_exception(e, extra: { projekt_import_id: projekt_import.id, stage: "chat" }) if defined?(Sentry)
    ServiceResult.failure(error: I18n.t("adm.projekts.imports.errors.ai_chat_failed", message: e.message))
  end

  private

  # The tools write straight into ProjektImport#ai_result, so the stored data is
  # already correct once a turn ends. Nothing regenerates the payload later.
  def edit_tools
    journal = ProjektImports::AiEditJournal.new(ai_chat_message: assistant_message)
    editor = ProjektImports::AiResultEditor.new(projekt_import: projekt_import, journal: journal)

    [
      Ai::Tools::ProjektImports::ReadImportData.new(editor: editor),
      Ai::Tools::ProjektImports::UpdateImportFields.new(editor: editor),
      Ai::Tools::ProjektImports::ReplaceImportPhase.new(editor: editor),
      Ai::Tools::ProjektImports::AddImportPhase.new(editor: editor),
      Ai::Tools::ProjektImports::RemoveImportPhase.new(editor: editor),
      Ai::Tools::ProjektImports::SetImportContentBlocks.new(editor: editor)
    ]
  end

  def build_history
    ai_chat = projekt_import.ai_chat
    return [] if ai_chat.blank?

    ai_chat.ai_chat_messages.order(created_at: :asc).filter_map do |msg|
      content = msg.content.to_s
      content = append_documents(content, msg.attached_documents) if msg.from_user?
      content = append_applied_edits(content, msg.tool_activity) if msg.from_ai?
      next nil if content.blank? && msg.attached_documents.blank?

      { role: msg.role, content: content }
    end
  end

  # Tool calls are not replayed as provider tool messages, so without this the
  # model only sees its own prose claiming a change and can be talked into
  # applying the same edit twice — against indices that have already shifted.
  def append_applied_edits(content, tool_activity)
    summaries = ProjektImports::AiEditJournal.summarize(tool_activity)
    return content if summaries.empty?

    applied = summaries.join("; ")

    "#{content}\n\n[Already applied to the stored import data: #{applied}]".strip
  end

  def append_documents(content, documents)
    docs = Array(documents).select { |d| d["extracted_text"].present? }
    return content if docs.empty?

    parts = docs.map do |doc|
      "--- Attached document: #{doc['name']} (#{doc['filetype']}) ---\n#{doc['extracted_text']}"
    end

    "#{content}\n\n#{parts.join("\n\n")}".strip
  end

  def extract_text(response)
    if response.respond_to?(:content) && response.content.is_a?(String)
      response.content
    elsif response.respond_to?(:text)
      response.text
    else
      response.to_s
    end
  end
end
