require "rails_helper"

describe Polls::AnswerAllowanceQuery do
  let(:citizen) { create(:user) }

  def question_of(vote_type, **options)
    create(:poll_question, votation_type: VotationType.new(vote_type: vote_type, **options))
  end

  def options_for(question, *titles)
    titles.map { |title| create(:poll_question_answer, question: question, title: title) }
  end

  def vote(question, title, weight: 1)
    Poll::Answer.create!(question: question, author: citizen, answer: title, answer_weight: weight)
  end

  def allowed?(question, title, weight: 1)
    Polls::AnswerAllowanceQuery.call(question: question, user: citizen, title: title, weight: weight)
  end

  it "never runs out for a single-choice question, a new choice replaces the old one" do
    question = question_of(:unique)
    options_for(question, "Ja", "Nein")
    vote(question, "Ja")

    expect(allowed?(question, "Nein")).to be true
  end

  describe "multiple choice" do
    let(:question) { question_of(:multiple, max_votes: 2) }

    before { options_for(question, "Bänke", "Bäume", "Brunnen") }

    it "allows choices up to the maximum" do
      vote(question, "Bänke")

      expect(allowed?(question, "Bäume")).to be true
    end

    it "refuses a further choice once the maximum is reached" do
      vote(question, "Bänke")
      vote(question, "Bäume")

      expect(allowed?(question, "Brunnen")).to be false
    end

    it "lets an option already chosen be chosen again" do
      vote(question, "Bänke")
      vote(question, "Bäume")

      expect(allowed?(question, "Bänke")).to be true
    end
  end

  describe "multiple choice with weight" do
    let(:question) { question_of(:multiple_with_weight, max_votes: 5, max_votes_per_answer: 3) }

    before { options_for(question, "Bänke", "Bäume") }

    it "caps the weight on a single option" do
      expect(allowed?(question, "Bänke", weight: 3)).to be true
      expect(allowed?(question, "Bänke", weight: 4)).to be false
    end

    it "caps the weight spread across all options" do
      vote(question, "Bänke", weight: 3)

      expect(allowed?(question, "Bäume", weight: 2)).to be true
      expect(allowed?(question, "Bäume", weight: 3)).to be false
    end
  end

  it "refuses visitors without an account" do
    question = question_of(:unique)
    options_for(question, "Ja")

    expect(Polls::AnswerAllowanceQuery.call(question: question, user: nil, title: "Ja")).to be false
  end
end
