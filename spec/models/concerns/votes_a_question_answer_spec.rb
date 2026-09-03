require "rails_helper"

describe VotesAQuestionAnswer do
  let(:target_locale) { (I18n.available_locales - [I18n.default_locale]).first }
  let(:question) { create(:poll_question) }
  let(:question_answer) do
    Globalize.with_locale(I18n.default_locale) do
      create(:poll_question_answer, question: question, title: "Source title")
    end
  end

  before do
    Globalize.with_locale(target_locale) { question_answer.update!(title: "Translated title") }
  end

  describe "resolving the answer a vote belongs to" do
    it "links a vote cast under the default-locale title" do
      vote = Poll::Answer.create!(question: question, author: create(:user), answer: "Source title")

      expect(vote.question_answer).to eq question_answer
    end

    it "links a vote cast under a translated title" do
      vote = Poll::Answer.create!(question: question, author: create(:user), answer: "Translated title")

      expect(vote.question_answer).to eq question_answer
    end

    it "links a booth result the same way" do
      result = Poll::PartialResult.create!(question: question, author: create(:user), amount: 3,
                                           origin: "booth", answer: "Translated title")

      expect(result.question_answer).to eq question_answer
    end

    it "keeps an explicitly given answer instead of resolving one" do
      other = create(:poll_question_answer, question: question, title: "Other title")

      vote = Poll::Answer.create!(question: question, author: create(:user),
                                  question_answer: other, answer: "Other title")

      expect(vote.question_answer).to eq other
    end
  end

  describe "consistency with the question" do
    it "rejects an answer belonging to another question" do
      foreign_answer = create(:poll_question_answer, title: "Source title")

      vote = Poll::Answer.new(question: question, author: create(:user),
                              question_answer: foreign_answer, answer: "Source title")

      expect(vote).not_to be_valid
      expect(vote.errors[:question_answer]).to be_present
    end
  end
end
