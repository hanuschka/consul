require "rails_helper"

describe ProjektPhase::FormularPhase, "guest participation" do
  let(:phase) do
    create(:projekt).projekt_phases.create!(type: "ProjektPhase::FormularPhase", active: true, user_status: "guest")
  end

  it "does not count anonymous answers against a guest who has not submitted anything" do
    FormularAnswer.create!(formular: phase.formular, submitter_id: nil, answers: { "field" => "anonymous" })
    guest = User.new(username: "guest-key", email: "guest-key@example.com", guest: true)

    expect(phase.formular.submissions_limit_reached_for?(guest)).to be true
    expect(ProjektPhase.find(phase.id).permission_problem(guest)).to be_nil
  end

  it "stops a saved guest at the submissions limit" do
    guest = create(:user, guest: true, email: "guest-key@example.com")
    FormularAnswer.create!(formular: phase.formular, submitter: guest, answers: { "field" => "mine" })

    expect(ProjektPhase.find(phase.id).permission_problem(guest)).to eq :submissions_limit_reached
  end
end
