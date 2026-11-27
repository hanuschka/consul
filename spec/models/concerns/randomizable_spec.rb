require "rails_helper"

describe Randomizable do
  describe ".sort_by_random" do
    it "shuffles search results that eager load associations" do
      matching_proposal = create(:proposal, title: "Bicycle lanes along the river")
      create(:proposal, title: "Longer library opening hours")

      shuffled_proposals = Proposal.for_render.search("bicycle").sort_by_random(1)

      expect(shuffled_proposals).to eq [matching_proposal]
    end
  end
end
