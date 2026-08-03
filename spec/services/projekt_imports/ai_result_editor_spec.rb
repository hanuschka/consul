require "rails_helper"

describe ProjektImports::AiResultEditor do
  let(:user) { create(:user) }
  let(:questions) { [{ "title" => "Frage eins?" }, { "title" => "Frage zwei?" }] }

  let(:ai_result) do
    {
      "title" => "Leben im Alter",
      "subtitle" => "Fortschreibung des Altenhilfeplans",
      "categories" => ["Soziales"],
      "content_blocks" => [{ "template_id" => 1, "content_data" => "Text" }],
      "phases" => [
        { "type" => "ProjektPhase::VotingPhase", "name" => "Abstimmung", "poll_questions" => questions },
        { "type" => "ProjektPhase::CommentPhase", "name" => "Diskussion" }
      ]
    }
  end

  let(:projekt_import) do
    ProjektImport.create!(user: user, status: "chatting", ai_result: ai_result)
  end

  let(:ai_chat) { AiChat.create!(resource: projekt_import) }
  let(:assistant_message) do
    ai_chat.ai_chat_messages.create!(role: "assistant", status: "running", content: "")
  end
  let(:journal) { ProjektImports::AiEditJournal.new(ai_chat_message: assistant_message) }
  let(:editor) do
    ProjektImports::AiResultEditor.new(projekt_import: projekt_import, journal: journal)
  end

  describe "#update_fields" do
    it "writes only the fields that were passed" do
      changed = editor.update_fields("title" => "Neuer Titel", "subtitle" => nil)

      expect(changed).to eq(["title"])
      expect(projekt_import.reload.ai_result["title"]).to eq("Neuer Titel")
      expect(projekt_import.ai_result["subtitle"]).to eq("Fortschreibung des Altenhilfeplans")
    end

    it "ignores keys that are not editable fields" do
      changed = editor.update_fields("phases" => [], "title" => "Neuer Titel")

      expect(changed).to eq(["title"])
      expect(projekt_import.reload.ai_result["phases"].size).to eq(2)
    end
  end

  describe "#replace_phase" do
    # This is the guarantee the old regenerate-everything finalize step could not
    # make: editing one phase cannot touch any other phase.
    it "leaves the other phases untouched" do
      editor.replace_phase(0, { "type" => "ProjektPhase::VotingPhase", "name" => "Umfrage" })

      phases = projekt_import.reload.ai_result["phases"]
      expect(phases[0]["name"]).to eq("Umfrage")
      expect(phases[1]).to eq(ai_result["phases"][1])
    end

    it "rejects an out of range index" do
      expect { editor.replace_phase(9, {}) }
        .to raise_error(ProjektImports::AiResultEditor::IndexError, /out of range/)
    end
  end

  describe "#add_phase and #remove_phase" do
    it "appends a phase and returns its index" do
      index = editor.add_phase("type" => "ProjektPhase::EventPhase")

      expect(index).to eq(2)
      expect(projekt_import.reload.ai_result["phases"].size).to eq(3)
    end

    it "removes the phase at the given index and returns it" do
      removed = editor.remove_phase(1)

      expect(removed["type"]).to eq("ProjektPhase::CommentPhase")
      expect(projekt_import.reload.ai_result["phases"].map { |p| p["type"] })
        .to eq(["ProjektPhase::VotingPhase"])
    end
  end

  describe "journalling" do
    # Without a persisted record of the edit, a ChatMessageJob retry replays the
    # turn against data the tools already changed.
    it "records each applied edit on the assistant message as it happens" do
      editor.update_fields("title" => "Neuer Titel")
      editor.remove_phase(1)

      expect(assistant_message.reload.tool_activity.map { |e| e["action"] })
        .to eq(%w[update_fields remove_phase])
    end

    it "records nothing when no field was actually changed" do
      editor.update_fields("title" => nil)

      expect(assistant_message.reload.tool_activity).to be_empty
    end
  end

  describe "readers" do
    it "summarises the overview without inlining nested resources" do
      overview = editor.overview

      expect(overview["title"]).to eq("Leben im Alter")
      expect(overview["phase_count"]).to eq(2)
      expect(overview["content_block_count"]).to eq(1)
      expect(overview).not_to have_key("phases")
    end

    it "returns phases in full so the chat can read poll questions" do
      expect(editor.phases.first["poll_questions"]).to eq(questions)
    end
  end
end
