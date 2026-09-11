require "rails_helper"

describe Poll::Question::Answer do
  describe "clearing randomize_position once a jump target is configured" do
    let(:poll) { create(:poll) }
    let(:question) { create(:poll_question, poll: poll, randomize_position: true) }
    let(:target) { create(:poll_question, poll: poll, randomize_position: true) }

    it "clears the flag on the question owning the answer and on the jump target" do
      create(:poll_question_answer, question: question, next_question_id: target.id)

      expect(question.reload.randomize_position).to be false
      expect(target.reload.randomize_position).to be false
    end

    it "leaves questions that are not part of the jump untouched" do
      bystander = create(:poll_question, poll: poll, randomize_position: true)

      create(:poll_question_answer, question: question, next_question_id: target.id)

      expect(bystander.reload.randomize_position).to be true
    end

    it "leaves the flag alone for an answer without a jump target" do
      create(:poll_question_answer, question: question)

      expect(question.reload.randomize_position).to be true
    end
  end

  describe "counting votes cast in a translated locale" do
    let(:target_locale) { (I18n.available_locales - [I18n.default_locale]).first }
    let(:voting_question) { create(:poll_question) }
    let(:answer) do
      Globalize.with_locale(I18n.default_locale) do
        create(:poll_question_answer, question: voting_question, title: "Source title")
      end
    end

    before do
      Globalize.with_locale(target_locale) { answer.update!(title: "Translated title") }
    end

    it "counts the vote in every locale's tally" do
      I18n.with_locale(target_locale) do
        Poll::Answer.create!(question: voting_question, author: create(:user), answer: "Translated title")
      end

      expect(answer.total_votes).to eq 1
      expect(answer.total_voters).to eq 1
      expect(I18n.with_locale(target_locale) { answer.total_votes }).to eq 1
    end

    it "counts a booth result recorded under the translated title" do
      I18n.with_locale(target_locale) do
        Poll::PartialResult.create!(question: voting_question, author: create(:user), amount: 4,
                                    origin: "booth", answer: "Translated title")
      end

      expect(answer.total_votes).to eq 4
    end
  end
end
