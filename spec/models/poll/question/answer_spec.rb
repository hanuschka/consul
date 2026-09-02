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
end
