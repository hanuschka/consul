require "rails_helper"

describe Mitmachbox::TestRun do
  def option(id, next_question_id: nil, ends_survey: false)
    { "id" => id, "label" => "Option #{id}", "position" => id % 10,
      "next_question_id" => next_question_id, "ends_survey" => ends_survey }
  end

  let(:questions) do
    [
      { "id" => 3, "position" => 3, "question_type" => "rating", "required" => false,
        "options" => [option(31), option(32)] },
      { "id" => 1, "position" => 1, "question_type" => "single_choice", "required" => true,
        "options" => [option(11, next_question_id: 3), option(12, ends_survey: true), option(13)] },
      { "id" => 2, "position" => 2, "question_type" => "multiple_choice", "required" => false,
        "options" => [option(21), option(22)] },
      { "id" => 4, "position" => 4, "question_type" => "single_choice", "required" => false,
        "options" => [option(41)] }
    ]
  end

  def run(answers = {}, answered: nil)
    Mitmachbox::TestRun.new(questions, answers: answers, answered_question_id: answered)
  end

  it "starts with the first question by position" do
    test_run = run

    expect(test_run.current_question["id"]).to eq 1
    expect([test_run.step, test_run.total]).to eq [1, 4]
  end

  it "follows a jump to its target" do
    expect(run({ 1 => [11] }, answered: "1").current_question["id"]).to eq 3
  end

  it "ends the run at an option that ends the survey" do
    expect(run({ 1 => [12] }, answered: "1")).to be_finished
  end

  it "continues in order after an option without a jump" do
    expect(run({ 1 => [13] }, answered: "1").current_question["id"]).to eq 2
  end

  it "keeps a required question until an answer is chosen" do
    test_run = run({}, answered: "1")

    expect(test_run).to be_missing_required_answer
    expect(test_run.current_question["id"]).to eq 1
  end

  it "lets an optional question pass without an answer" do
    test_run = run({ 1 => [13] }, answered: "2")

    expect(test_run).not_to be_missing_required_answer
    expect(test_run.current_question["id"]).to eq 3
  end

  it "finishes after the last question" do
    expect(run({ 1 => [13], 4 => [41] }, answered: "4")).to be_finished
  end

  it "shows a conditional question only if its condition is met" do
    questions.last["condition"] = { "question_id" => 1, "option_ids" => [13] }

    expect(run({ 1 => [13], 3 => [31] }, answered: "3").current_question["id"]).to eq 4
    expect(run({ 1 => [13], 3 => [31] }, answered: "3")).not_to be_finished
    questions.last["condition"] = { "question_id" => 1, "option_ids" => [11] }
    expect(run({ 1 => [13], 3 => [31] }, answered: "3")).to be_finished
  end

  it "carries the earlier answers but not the one being asked" do
    test_run = run({ 1 => [11], 3 => [] }, answered: "1")

    expect(test_run.previous_answers).to eq(1 => [11])
  end
end
