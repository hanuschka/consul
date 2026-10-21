# Records every mutation a chat turn applies to ProjektImport#ai_result, on the
# assistant message that caused it. Written through immediately rather than at
# the end of the turn: a job that dies mid-turn must still leave evidence that
# the edits landed, otherwise the retry replays them against already-edited data.
#
# Destructive edits are not applied by the model at all. They are recorded here
# as proposals, and only the administrator's click turns one into a real edit,
# which is then journaled like any other.
class ProjektImports::AiEditJournal
  PENDING = "pending".freeze
  APPLIED = "applied".freeze
  DISCARDED = "discarded".freeze

  attr_reader :ai_chat_message

  def initialize(ai_chat_message:)
    @ai_chat_message = ai_chat_message
  end

  def record(action, details = {})
    entry = { "action" => action.to_s, "details" => details.stringify_keys }
    ai_chat_message.update!(tool_activity: entries + [entry])

    entry
  end

  def propose(action, details = {})
    entry = {
      "action" => action.to_s,
      "details" => details.stringify_keys,
      "proposal_id" => SecureRandom.uuid,
      "state" => PENDING
    }
    ai_chat_message.update!(tool_activity: entries + [entry])

    entry
  end

  def pending_proposal(proposal_id)
    entries.find do |entry|
      entry["proposal_id"] == proposal_id && entry["state"] == PENDING
    end
  end

  def resolve_proposal!(proposal_id, state)
    updated = entries.map do |entry|
      next entry if entry["proposal_id"] != proposal_id

      entry.merge("state" => state)
    end

    ai_chat_message.update!(tool_activity: updated)
  end

  def self.proposals(entries)
    Array(entries).select { |entry| entry.key?("proposal_id") }
  end

  def self.pending_proposals(entries)
    proposals(entries).select { |entry| entry["state"] == PENDING }
  end

  # A journal entry that changed the stored data: a direct edit, or a proposal
  # the administrator applied (which also produced a direct entry of its own).
  def self.applied?(entry)
    !entry.key?("proposal_id")
  end

  def self.summarize(entries)
    Array(entries).map { |entry| describe(entry) }.compact
  end

  # Rendered both into the chat bubble the admin reads and into the replayed
  # history the model reads, so it follows the conversation's locale. An action
  # with no key yields nil and is dropped, keeping old entries safe to replay.
  # An applied proposal describes as nothing because the edit it turned into
  # has an entry of its own.
  def self.describe(entry)
    edit = describe_edit(entry)
    return nil if edit.blank?

    case entry["state"]
    when nil then edit
    when PENDING then translate(:proposed, edit: edit)
    when DISCARDED then translate(:discarded, edit: edit)
    end
  end

  def self.describe_edit(entry)
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
