require "rails_helper"

describe Whatsapp::Polls::BallotEndingQuery do
  let(:user) { create(:user) }
  let(:poll) { create(:poll) }
  let!(:choice_question) { create(:poll_question, poll: poll, title: "Lieblingsfarbe") }
  let!(:option) { create(:poll_question_answer, question: choice_question, title: "Blau") }
  let!(:map_question) { create(:poll_question, :map_points, poll: poll, title: "Kartenpunkt") }

  def ending
    described_class.call(poll: poll, user: user)
  end

  def answer_choice!
    choice_question.find_or_initialize_user_answer(user, option).save_and_record_voter_participation
  end

  def place_map_points!(count)
    answer = map_question.answers.create!(author: user)

    count.times { answer.map_points.create!(latitude: 51.5, longitude: 7.4) }
  end

  it "is skipped where no question holds an answer" do
    expect(ending.outcome).to eq Whatsapp::Polls::AdvanceBallotService::SKIPPED
    expect(ending.answers).to be_empty
    expect(ending.unanswered_questions).to match_array [choice_question, map_question]
  end

  it "is partly answered where the map question was skipped" do
    answer_choice!

    expect(ending.outcome).to eq Whatsapp::Polls::AdvanceBallotService::PARTLY_ANSWERED
    expect(ending.answers.map(&:question)).to eq [choice_question]
    expect(ending.unanswered_questions).to eq [map_question]
  end

  it "keeps a map question given fewer points than it asks for out of the unanswered ones" do
    answer_choice!
    place_map_points!(1)

    expect(ending.outcome).to eq Whatsapp::Polls::AdvanceBallotService::PARTLY_ANSWERED
    expect(ending.unanswered_questions).to be_empty
  end

  it "is completed where every question holds its full answer" do
    answer_choice!
    place_map_points!(3)

    expect(ending.outcome).to eq Whatsapp::Polls::AdvanceBallotService::COMPLETED
    expect(ending.unanswered_questions).to be_empty
  end
end
