require "rails_helper"

describe Mitmachbox::SurveyPath, "#progress_total" do
  def option(id, position, next_question_id: nil, ends_survey: false)
    { "id" => id, "position" => position, "next_question_id" => next_question_id,
"ends_survey" => ends_survey }
  end

  def question(id, type, required, options, condition: nil)
    { "id" => id, "position" => id, "question_type" => type, "required" => required,
      "options" => options, "condition" => condition }
  end

  let(:basic) do
    [
      question(1, "single_choice", true,
[option(11, 1, next_question_id: 3), option(12, 2, ends_survey: true)]),
      question(2, "single_choice", false, (1..5).map { |n| option(20 + n, n) }),
      question(3, "multiple_choice", false, (1..4).map { |n| option(30 + n, n) })
    ]
  end

  let(:branching) do
    [
      question(1, "single_choice", true, [option(11, 1), option(12, 2), option(13, 3, ends_survey: true)]),
      question(2, "single_choice", false, [option(21, 1)],
condition: { "question_id" => 1, "option_ids" => [12] }),
      question(3, "rating", false, []),
      question(4, "single_choice", false, [option(41, 1)])
    ]
  end

  it "leaves the total open while the remaining paths differ in length" do
    expect(Mitmachbox::SurveyPath.new(basic).progress_total(1, 1, [])).to be_nil
    expect(Mitmachbox::SurveyPath.new(branching).progress_total(1, 1, [])).to be_nil
  end

  it "counts the total once every remaining path has the same length" do
    expect(Mitmachbox::SurveyPath.new(basic).progress_total(2, 2, [])).to eq 3
    expect(Mitmachbox::SurveyPath.new(basic).progress_total(3, 3, [])).to eq 3
    expect(Mitmachbox::SurveyPath.new(branching).progress_total(2, 2, [])).to eq 4
    expect(Mitmachbox::SurveyPath.new(branching).progress_total(4, 4, [])).to eq 4
  end

  it "follows the answers given so far through conditional questions" do
    path = Mitmachbox::SurveyPath.new(branching)

    expect(path.progress_total(4, 3, [[1, 12], [2, 21]])).to eq 3
    expect(path.progress_total(3, 2, [[1, 11]])).to eq 3
  end
end
