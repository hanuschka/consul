require "rails_helper"

describe ProjektImports::CreateProjektFromImportService do
  let(:user) { create(:user) }

  def build_import(ai_result)
    ProjektImport.create!(
      user: user,
      status: "submitting",
      content_locale: "de",
      ai_result: ai_result
    )
  end

  def voting_phase_data(poll_questions:)
    {
      "type" => "ProjektPhase::VotingPhase",
      "name" => "Abstimmung",
      "start_date" => nil,
      "end_date" => nil,
      "description" => nil,
      "cta_button_name" => nil,
      "user_status" => nil,
      "poll_questions" => poll_questions,
      "events" => [],
      "milestones" => [],
      "arguments" => [],
      "notifications" => [],
      "progress_bars" => [],
      "budget" => nil,
      "iframe" => nil,
      "livestreams" => [],
      "point_of_interest_categories" => []
    }
  end

  def rating_scale_question
    {
      "title" => "Wie zufrieden sind Sie mit Ihrem Leben in Friedrichsdorf?",
      "description" => nil,
      "vote_type" => "rating_scale",
      "min_rating_scale_label" => "Sehr unzufrieden",
      "max_rating_scale_label" => "Sehr zufrieden",
      "answers" => [
        { "title" => "1", "description" => nil },
        { "title" => "2", "description" => nil },
        { "title" => "3", "description" => nil }
      ]
    }
  end

  def unique_question
    {
      "title" => "Welche Angebote waeren fuer Sie kuenftig interessant?",
      "description" => "Mehrfachnennung moeglich",
      "vote_type" => "unique",
      "min_rating_scale_label" => nil,
      "max_rating_scale_label" => nil,
      "answers" => [
        { "title" => "Fahrdienste", "description" => "Begleitung zu Terminen" },
        { "title" => "Haushaltshilfe", "description" => nil }
      ]
    }
  end

  def ai_result_with(phases)
    {
      "title" => "Leben im Alter in Friedrichsdorf",
      "subtitle" => "Fortschreibung des Altenhilfeplans",
      "content_blocks" => [],
      "projekt_start_date" => nil,
      "projekt_end_date" => nil,
      "categories" => [],
      "sdg_codes" => [],
      "phases" => phases,
      "projekt_settings" => {},
      "projekt_phase_settings" => {},
      "image_prompt" => nil,
      "needs_clarification" => false,
      "clarification_questions" => []
    }
  end

  describe "a voting phase carrying poll questions" do
    let(:poll_questions) { [rating_scale_question, unique_question] }
    let(:projekt_import) { build_import(ai_result_with([voting_phase_data(poll_questions: poll_questions)])) }
    let(:result) { ProjektImports::CreateProjektFromImportService.call(projekt_import: projekt_import) }

    # The builders swallow RecordInvalid into ProjektImport#warnings, so a green
    # "success" says nothing on its own. An empty warnings array is what proves
    # every builder actually persisted its records.
    it "completes without recording any warning" do
      expect(result).to be_success
      expect(projekt_import.reload.warnings).to be_empty
    end

    it "creates the poll questions on the voting phase" do
      phase = result.data[:projekt].projekt_phases.find { |p| p.type == "ProjektPhase::VotingPhase" }

      expect(phase.poll).to be_present
      expect(phase.poll.questions.map(&:title)).to match_array(poll_questions.map { |q| q["title"] })
    end

    it "gives every question an author, a votation type and an order" do
      questions = result.data[:projekt].polls.first.questions

      expect(questions.map(&:author)).to all(eq(user))
      expect(questions.map(&:given_order)).to match_array([1, 2])
      expect(questions.map { |q| q.votation_type.vote_type }).to match_array(%w[rating_scale unique])
    end

    it "carries the rating scale labels onto the votation type" do
      question = result.data[:projekt].polls.first.questions
        .find { |q| q.title == rating_scale_question["title"] }

      expect(question.votation_type.min_rating_scale_label).to eq("Sehr unzufrieden")
      expect(question.votation_type.max_rating_scale_label).to eq("Sehr zufrieden")
    end

    it "creates ordered answers and tolerates a missing answer description" do
      question = result.data[:projekt].polls.first.questions
        .find { |q| q.title == unique_question["title"] }

      expect(question.question_answers.map(&:title)).to eq(%w[Fahrdienste Haushaltshilfe])
      expect(question.question_answers.map(&:given_order)).to eq([1, 2])
      expect(question.question_answers.last.description).to be_blank
    end
  end

  describe "a voting phase the AI could not derive questions for" do
    let(:projekt_import) { build_import(ai_result_with([voting_phase_data(poll_questions: [])])) }
    let(:result) { ProjektImports::CreateProjektFromImportService.call(projekt_import: projekt_import) }

    it "still creates the projekt but records a warning" do
      expect(result).to be_success

      warnings = projekt_import.reload.warnings.map { |warning| warning["message"] }
      expect(warnings.size).to eq(1)
      expect(warnings.first).to include("Abstimmung")
    end

    it "does not leave an empty poll behind" do
      phase = result.data[:projekt].projekt_phases.find { |p| p.type == "ProjektPhase::VotingPhase" }

      expect(phase.poll).to be_nil
    end
  end
end
