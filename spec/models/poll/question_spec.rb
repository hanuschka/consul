require "rails_helper"

describe Poll::Question do
  let(:poll) { create(:poll) }
  let(:question) { create(:poll_question, poll: poll) }

  describe "#randomize_position_block_reason" do
    it "is nil for an independent root question" do
      expect(question.randomize_position_block_reason).to be_nil
      expect(question).to be_randomize_position_possible
    end

    it "is :bundle for a bundle question" do
      bundle = create(:poll_question, :bundle, poll: poll)

      expect(bundle.randomize_position_block_reason).to eq(:bundle)
      expect(bundle).not_to be_randomize_position_possible
    end

    it "is :bundle for a question nested in a bundle" do
      bundle = create(:poll_question, :bundle, poll: poll)
      nested = create(:poll_question, poll: poll, parent_question: bundle)

      expect(nested.randomize_position_block_reason).to eq(:bundle)
    end

    it "is :contextualization for a contextualized question" do
      source = create(:poll_question, poll: poll)
      question.update!(contextualize_by_poll_question_id: source.id)

      expect(question.randomize_position_block_reason).to eq(:contextualization)
    end

    it "is :contextualization for a question used as a context source" do
      dependent = create(:poll_question, poll: poll)
      dependent.update!(contextualize_by_poll_question_id: question.id)

      expect(question.reload.randomize_position_block_reason).to eq(:contextualization)
    end

    it "is :branching when one of its own answers jumps to another question" do
      target = create(:poll_question, poll: poll)
      create(:poll_question_answer, question: question, next_question_id: target.id)

      expect(question.reload.randomize_position_block_reason).to eq(:branching)
    end

    it "is :branching when an answer of another question jumps to it" do
      other = create(:poll_question, poll: poll)
      create(:poll_question_answer, question: other, next_question_id: question.id)

      expect(question.reload.randomize_position_block_reason).to eq(:branching)
    end
  end

  describe "#answers_in_participant_order" do
    let(:question) { Poll::Question.new(id: 42, randomize_answers: true) }
    let(:regular) { (1..5).map { |id| build_answer(id, open_answer: false) } }
    let(:open) { build_answer(6, open_answer: true) }
    let(:answers) { [*regular, open] }

    def build_answer(id, open_answer:)
      Poll::Question::Answer.new(id: id, open_answer: open_answer)
    end

    it "keeps the open answer last for every participant" do
      orders = (1..20).map { |number| question.answers_in_participant_order(answers, "participant-#{number}") }

      expect(orders.map(&:last)).to all(eq(open))
      expect(orders.map { |order| order.first(5) }).to all(match_array(regular))
    end

    it "returns the same order for the same participant" do
      expect(question.answers_in_participant_order(answers, "participant-a"))
        .to eq(question.answers_in_participant_order(answers, "participant-a"))
    end

    it "varies the order between participants" do
      orders = (1..20).map do |number|
        question.answers_in_participant_order(answers, "participant-#{number}").map(&:id)
      end

      expect(orders.uniq.size).to be > 1
    end

    it "leaves the configured order untouched when randomization is off" do
      question.randomize_answers = false

      expect(question.answers_in_participant_order(answers, "participant-a")).to eq(answers)
    end

    it "is not possible for a rating scale question" do
      question.votation_type = VotationType.new(vote_type: :rating_scale)

      expect(question).not_to be_randomize_answers_possible
    end

    it "leaves the order untouched for a rating scale even when the flag is set" do
      question.votation_type = VotationType.new(vote_type: :rating_scale)

      expect(question.answers_in_participant_order(answers, "participant-a")).to eq(answers)
    end

    it "does not mutate the collection it is given" do
      original = answers.dup

      question.answers_in_participant_order(answers, "participant-a")

      expect(answers).to eq(original)
    end
  end

  describe ".in_configured_order" do
    let!(:first) { create(:poll_question, poll: poll, given_order: 1) }
    let!(:source) { create(:poll_question, poll: poll, given_order: 2) }
    let!(:template) do
      create(:poll_question, poll: poll, given_order: 3, contextualize_by_poll_question_id: source.id)
    end
    let!(:last) { create(:poll_question, poll: poll, given_order: 4) }

    before do
      create(:poll_question_answer, question: source)
      template.regenerate_contexted_clones
    end

    it "positions a contexted clone by the given_order of its template" do
      clone = template.contexted_clones.reload.first
      clone.update_column(:given_order, 99)

      ordered = poll.questions.root_questions.in_configured_order.pluck(:id)

      expect(ordered).to eq([first.id, source.id, template.id, clone.id, last.id])
    end

    it "keeps questions without a template on their own given_order" do
      ordered = poll.questions.root_questions.in_configured_order.pluck(:id)

      expect(ordered.first(3)).to eq([first.id, source.id, template.id])
      expect(ordered.last).to eq(last.id)
    end
  end

  describe "randomize_position" do
    it "keeps the flag on an independent root question" do
      question.update!(randomize_position: true)

      expect(question.reload.randomize_position).to be true
    end

    it "clears the flag on save once the question is no longer eligible" do
      question.update!(randomize_position: true)

      question.update!(bundle_question: true)

      expect(question.reload.randomize_position).to be false
    end

    it "cannot be set on a question that is already ineligible" do
      bundle = create(:poll_question, :bundle, poll: poll)

      bundle.update!(randomize_position: true)

      expect(bundle.reload.randomize_position).to be false
    end
  end
end
