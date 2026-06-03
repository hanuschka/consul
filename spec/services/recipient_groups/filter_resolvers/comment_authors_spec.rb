require "rails_helper"

describe RecipientGroups::FilterResolvers::CommentAuthors do
  let(:phase) { create(:projekt_phase) }
  let!(:commenter) { create(:user, email: "c@x.test", skip_password_validation: true) }
  let!(:other) { create(:user, email: "o@x.test", skip_password_validation: true) }

  before do
    create(:comment, commentable: phase, user: commenter)
  end

  it "returns commenters scoped to a phase" do
    expect(
      described_class.new("commentable_type" => "ProjektPhase", "commentable_id" => phase.id).emails
    ).to contain_exactly("c@x.test")
  end

  it "returns no one when scoped to an unrelated commentable" do
    other_phase = create(:projekt_phase)
    expect(
      described_class.new("commentable_type" => "ProjektPhase", "commentable_id" => other_phase.id).emails
    ).to eq([])
  end

  it "returns all global commenters when commentable_id is blank" do
    expect(
      described_class.new({}).emails
    ).to contain_exactly("c@x.test")
  end
end
