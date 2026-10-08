require "rails_helper"

describe Whatsapp::Contributions::RegisterSupportService do
  # The bot takes no support from a proposal's author. One they gave on the page
  # before is answered as already given, so the way back out of it stays open.
  let(:user) { double(:user, id: 1) }
  let(:proposal) { double(:proposal, id: 482, author_id: 1) }

  before do
    allow(Proposal).to receive_message_chain(:not_retired, :find_by)
      .with(id: 482).and_return(proposal)
  end

  def register
    Whatsapp::Contributions::RegisterSupportService.call(proposal_id: 482, user: user)
  end

  it "refuses the citizen's own proposal without registering a vote" do
    allow(proposal).to receive(:voted_up_by?).with(user).and_return(false)

    expect(register).to eq(:own_proposal)
  end

  it "answers a support the author gave on the page before as already given" do
    allow(proposal).to receive(:voted_up_by?).with(user).and_return(true)

    expect(register).to eq(:already_supported)
  end
end
