require "rails_helper"

describe Poll::Answer do
  let(:poll) { create(:poll) }
  let(:author) { create(:user) }
  let(:option_question) { create(:poll_question, poll: poll) }
  let(:map_question) { create(:poll_question, :map_points, poll: poll) }

  describe "map_points? delegation" do
    it "reports false for an option question" do
      expect(option_question.answers.new.map_points?).to be false
    end

    it "reports true for a map question" do
      expect(map_question.answers.new.map_points?).to be true
    end

    it "is nil-safe when the answer has no question yet" do
      expect(Poll::Answer.new.map_points?).to be_nil
      expect(Poll::Answer.new).not_to be_valid
    end
  end

  describe "the option validations" do
    it "requires the answer to be one of the question's options" do
      create(:poll_question_answer, question: option_question, title: "Bench")

      expect(option_question.answers.new(author: author, answer: "Bench")).to be_valid
      expect(option_question.answers.new(author: author, answer: "Fountain")).not_to be_valid
    end

    it "does not apply to a map question, which has no options" do
      answer = map_question.answers.new(author: author)

      expect(answer).to be_valid
      expect(answer.answer).to be_nil
    end
  end

  describe "#save_and_record_voter_participation" do
    it "records the author as a voter of the poll" do
      answer = map_question.answers.new(author: author)

      expect { answer.save_and_record_voter_participation }
        .to change { Poll::Voter.where(poll: poll, user: author).count }.by(1)
    end
  end

  describe "map points" do
    let(:answer) do
      map_question.answers.new(author: author).tap(&:save_and_record_voter_participation)
    end

    it "keeps them alongside the answer" do
      answer.map_points.create!(latitude: 50.9, longitude: 7.1)

      expect(answer.reload.map_points.count).to eq(1)
    end

    it "is destroyed with them when the answer is destroyed" do
      point = answer.map_points.create!(latitude: 50.9, longitude: 7.1)

      answer.destroy!

      expect(Poll::Answer::MapPoint.where(id: point.id)).not_to exist
    end

    # Poll#go_live! purges answers with delete_all, which skips Rails callbacks,
    # so the cascade has to come from the foreign key.
    it "is removed by the database when answers are purged without callbacks" do
      point = answer.map_points.create!(latitude: 50.9, longitude: 7.1)

      Poll::Answer.where(id: answer.id).delete_all

      expect(Poll::Answer::MapPoint.where(id: point.id)).not_to exist
    end
  end
end
