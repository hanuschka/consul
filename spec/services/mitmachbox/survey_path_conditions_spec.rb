require "rails_helper"

describe Mitmachbox::SurveyPath do
  describe "display conditions" do
    let(:questions) do
      [
        { "id" => 1, "position" => 1, "question_type" => "single_choice",
          "options" => [{ "id" => 11 }, { "id" => 12 }] },
        { "id" => 2, "position" => 2, "question_type" => "single_choice",
          "options" => [{ "id" => 21, "next_question_id" => 4 }, { "id" => 22 }] },
        { "id" => 3, "position" => 3, "question_type" => "single_choice", "options" => [{ "id" => 31 }] },
        { "id" => 4, "position" => 4, "question_type" => "single_choice", "options" => [{ "id" => 41 }],
          "condition" => { "question_id" => 1, "option_ids" => [12] }},
        { "id" => 5, "position" => 5, "question_type" => "single_choice", "options" => [{ "id" => 51 }] }
      ]
    end

    let(:path) { Mitmachbox::SurveyPath.new(questions) }

    it "shows a conditional question when its condition is met" do
      expect(path.reached_question_ids(1 => [12])).to eq([1, 2, 3, 4, 5])
    end

    it "skips it otherwise and shows the questions in between as usual" do
      expect(path.reached_question_ids(1 => [11])).to eq([1, 2, 3, 5])
    end

    it "treats an unanswered source question as not met" do
      expect(path.reached_question_ids({})).to eq([1, 2, 3, 5])
    end

    it "still checks the condition of a question reached by a jump" do
      expect(path.reached_question_ids(1 => [11], 2 => [21])).to eq([1, 2, 5])
      expect(path.reached_question_ids(1 => [12], 2 => [21])).to eq([1, 2, 4, 5])
    end
  end
end
