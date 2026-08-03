# Records every mutation a chat turn applies to ProjektImport#ai_result, on the
# assistant message that caused it. Written through immediately rather than at
# the end of the turn: a job that dies mid-turn must still leave evidence that
# the edits landed, otherwise the retry replays them against already-edited data.
class ProjektImports::AiEditJournal
  attr_reader :ai_chat_message

  def initialize(ai_chat_message:)
    @ai_chat_message = ai_chat_message
  end

  def record(action, details = {})
    entry = { "action" => action.to_s, "details" => details.stringify_keys }
    ai_chat_message.update!(tool_activity: entries + [entry])

    entry
  end

  def self.summarize(entries)
    Array(entries).map { |entry| describe(entry) }.compact
  end

  # Rendered both into the chat bubble the admin reads and into the replayed
  # history the model reads, so it follows the conversation's locale. An action
  # with no key yields nil and is dropped, keeping old entries safe to replay.
  def self.describe(entry)
    details = entry["details"] || {}

    case entry["action"]
    when "update_fields"
      translate(:update_fields, fields: Array(details["fields"]).join(", "))
    when "replace_phase"
      translate(:replace_phase, index: details["phase_index"])
    when "add_phase"
      translate(:add_phase, index: details["phase_index"], type: phase_label(details["type"]))
    when "remove_phase"
      translate(:remove_phase, type: phase_label(details["type"]))
    when "replace_content_blocks"
      translate(:replace_content_blocks, count: details["count"])
    end
  end

  def self.translate(key, **interpolations)
    I18n.t("adm.projekts.imports.applied_edits.#{key}", **interpolations)
  end

  # The raw type identifier would otherwise reach both the admin's chat bubble
  # and the replayed history the model reads, showing it the very form the
  # system prompt forbids it from writing as a phase name.
  def self.phase_label(type)
    return "" if type.blank?

    ProjektPhase.type_label_for(type)
  end

  private

  def entries
    Array(ai_chat_message.tool_activity)
  end
end
