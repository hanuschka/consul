require "rails_helper"

describe "Proposal submission", type: :request do
  let(:user) { create(:user) }

  let(:projekt_phase) do
    create(:proposal_phase, active: true, start_date: 1.day.ago, end_date: 1.day.from_now).tap do |phase|
      phase.projekt.update!(activated: true)
    end
  end

  let(:proposal_params) do
    {
      proposal: {
        projekt_phase_id: projekt_phase.id,
        resource_terms: "1",
        translations_attributes: {
          "0" => {
            locale: I18n.default_locale,
            title: "Mehr Bänke im Stadtpark",
            description: "Damit man sich auf dem Weg ausruhen kann."
          }
        }
      }
    }
  end

  before do
    InvisibleCaptcha.timestamp_enabled = false
    login_as(user)
  end

  after { InvisibleCaptcha.timestamp_enabled = true }

  it "publishes the proposal at once and emails the author" do
    expect { post proposals_path, params: proposal_params }
      .to change(Proposal, :count).by(1)
      .and have_enqueued_mail(Mailer, :proposal_created)

    expect(Proposal.last).to be_published
  end

  it "holds the proposal back for admin acceptance when the phase requires it" do
    projekt_phase.settings.find_by!(key: "feature.general.require_admin_acceptance").update!(value: "active")

    post proposals_path, params: proposal_params

    expect(Proposal.last.admin_accepted).to be false
  end
end
