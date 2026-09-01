require "rails_helper"

describe Poll do
  describe "#questions_in_participant_order" do
    let(:poll) { Poll.new(id: 42) }
    let(:pinned_first) { build_question(1, randomize_position: false) }
    let(:pinned_second) { build_question(2, randomize_position: false) }
    let(:flagged) { (3..7).map { |id| build_question(id, randomize_position: true) } }
    let(:questions) { [pinned_first, pinned_second, *flagged] }

    def build_question(id, randomize_position:)
      Poll::Question.new(id: id, randomize_position: randomize_position)
    end

    it "keeps the unflagged questions in their configured slots" do
      ordered = poll.questions_in_participant_order(questions, "participant-a")

      expect(ordered.first(2)).to eq([pinned_first, pinned_second])
      expect(ordered.drop(2)).to match_array(flagged)
    end

    it "only rewrites the slots the flagged questions occupy" do
      mixed = [flagged[0], pinned_first, flagged[1], pinned_second, flagged[2]]

      ordered = poll.questions_in_participant_order(mixed, "participant-a")

      expect(ordered[1]).to eq(pinned_first)
      expect(ordered[3]).to eq(pinned_second)
      expect(ordered.values_at(0, 2, 4)).to match_array(flagged.first(3))
    end

    it "returns the same order for the same participant" do
      expect(poll.questions_in_participant_order(questions, "participant-a"))
        .to eq(poll.questions_in_participant_order(questions, "participant-a"))
    end

    it "varies the order between participants" do
      orders = (1..20).map do |number|
        poll.questions_in_participant_order(questions, "participant-#{number}").map(&:id)
      end

      expect(orders.uniq.size).to be > 1
    end

    it "leaves the order untouched when only one question is flagged" do
      single = [pinned_first, pinned_second, flagged.first]

      expect(poll.questions_in_participant_order(single, "participant-a")).to eq(single)
    end

    it "leaves the order untouched when no question is flagged" do
      pinned = [pinned_first, pinned_second]

      expect(poll.questions_in_participant_order(pinned, "participant-a")).to eq(pinned)
    end

    it "does not mutate the collection it is given" do
      original = questions.dup

      poll.questions_in_participant_order(questions, "participant-a")

      expect(questions).to eq(original)
    end
  end
end
