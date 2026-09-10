require "rails_helper"

describe Mitmachbox::SubmitWebResponseService do
  let(:projekt_phase) { create(:mitmachbox_phase) }
  let(:user) { create(:user) }
  let(:answers) { [{ question_id: 1, option_id: 2 }] }
  let(:responses) { instance_double(Mitmachbox::Resources::Responses) }
  let(:client) { instance_double(Mitmachbox::Client, responses: responses) }

  before do
    allow(Mitmachbox::Client).to receive(:new).with(anonymous: true).and_return(client)
  end

  def submit(version_id: 42)
    Mitmachbox::SubmitWebResponseService.call(projekt_phase: projekt_phase, user: user,
                         survey_version_id: version_id, answers: answers)
  end

  it "submits an anonymous participant key derived from the user and version" do
    expected_key = Mitmachbox.participant_key(user_id: user.id, survey_version_id: 42)

    expect(responses).to receive(:create).with(
      projekt_phase.mitmachbox_survey_id,
      participant_key: expected_key,
      survey_version_id: 42,
      answers: answers
    ).and_return("status" => "created", "id" => 9)

    expect(submit).to eq("created")
  end

  it "records the participation locally" do
    allow(responses).to receive(:create).and_return("status" => "created", "id" => 9)

    expect { submit }.to change(MitmachboxParticipation, :count).by(1)

    participation = MitmachboxParticipation.last
    expect(participation.projekt_phase).to eq(projekt_phase)
    expect(participation.user).to eq(user)
    expect(participation.survey_version_id).to eq(42)
  end

  it "does not record a second participation for the same version" do
    allow(responses).to receive(:create).and_return("status" => "created", "id" => 9)
    submit

    expect { submit }.not_to change(MitmachboxParticipation, :count)
  end

  it "records a fresh participation once a new version is published" do
    allow(responses).to receive(:create).and_return("status" => "created", "id" => 9)
    submit

    expect { submit(version_id: 43) }.to change(MitmachboxParticipation, :count).by(1)
  end

  it "does not record participation when the remote call fails" do
    allow(responses).to receive(:create).and_raise(Mitmachbox::Error, "boom")

    expect { submit }.to raise_error(Mitmachbox::Error)
    expect(MitmachboxParticipation.count).to eq(0)
  end
end
