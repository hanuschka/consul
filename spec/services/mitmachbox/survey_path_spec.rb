require "rails_helper"

describe Mitmachbox::SurveyPath do
  let(:questions) do
    [
      { "id" => 1, "position" => 1, "question_type" => "single_choice",
        "options" => [{ "id" => 10, "next_question_id" => nil, "ends_survey" => false },
                      { "id" => 11, "next_question_id" => 3, "ends_survey" => false },
                      { "id" => 12, "next_question_id" => nil, "ends_survey" => true }] },
      { "id" => 2, "position" => 2, "question_type" => "multiple_choice",
        "options" => [{ "id" => 20 }, { "id" => 21 }] },
      { "id" => 3, "position" => 3, "question_type" => "single_choice",
        "options" => [{ "id" => 30 }] }
    ]
  end

  let(:path) { Mitmachbox::SurveyPath.new(questions) }

  describe "#reached_question_ids" do
    it "walks the plain order when the chosen option has no follow-up" do
      expect(path.reached_question_ids(1 => [10])).to eq([1, 2, 3])
    end

    it "skips the questions between a choice and its follow-up" do
      expect(path.reached_question_ids(1 => [11])).to eq([1, 3])
    end

    it "ends the run on an option that closes the survey" do
      expect(path.reached_question_ids(1 => [12])).to eq([1])
    end

    it "stays on the default path when the branching question is unanswered" do
      expect(path.reached_question_ids({})).to eq([1, 2, 3])
    end
  end

  describe "#on_path" do
    it "drops answers to questions the run never reached" do
      answers = [{ question_id: 1, option_id: 11 },
                 { question_id: 2, option_id: 20 },
                 { question_id: 3, option_id: 30 }]

      expect(path.on_path(answers)).to eq([{ question_id: 1, option_id: 11 },
                                           { question_id: 3, option_id: 30 }])
    end

    it "keeps every answer of a run that took the default path" do
      answers = [{ question_id: 1, option_id: 10 }, { question_id: 2, option_id: 20 }]

      expect(path.on_path(answers)).to eq(answers)
    end
  end
end
