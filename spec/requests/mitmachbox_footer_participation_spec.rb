require "rails_helper"

describe "Answering a Mitmachbox survey from the projekt footer", type: :request do
  let(:projekt) { create(:projekt) }
  let(:projekt_phase) do
    create(:mitmachbox_phase, projekt: projekt, active: true)
  end
  let(:user) { create(:user) }

  let(:survey) do
    {
      "state" => "open",
      "survey_id" => 7,
      "version_id" => 42,
      "questions" => [
        {
          "id" => 1, "prompt" => "Single", "question_type" => "single_choice", "required" => true,
          "options" => [{ "id" => 10, "label" => "A" }, { "id" => 11, "label" => "B" }]
        },
        {
          "id" => 2, "prompt" => "Multi", "question_type" => "multiple_choice", "required" => false,
          "options" => [{ "id" => 20, "label" => "X" }, { "id" => 21, "label" => "Y" }]
        }
      ]
    }
  end

  before do
    allow(Mitmachbox::PublicSurveyService).to receive(:call).and_return(survey)
    allow(Mitmachbox::SubmitWebResponseService).to receive(:call).and_return("created")
  end

  def submit(answers)
    post mitmachbox_response_projekt_phase_path(projekt_phase), params: { mitmachbox_answers: answers }
  end

  def flash_notice
    request.flash[:notice]
  end

  def flash_alert
    request.flash[:alert]
  end

  context "as a signed-in user" do
    before { login_as(user) }

    it "submits the selected options and thanks the participant" do
      expect(Mitmachbox::SubmitWebResponseService).to receive(:call).with(
        projekt_phase: projekt_phase,
        user: user,
        survey_version_id: 42,
        answers: [
          { question_id: 1, option_id: 10 },
          { question_id: 2, option_id: 20 },
          { question_id: 2, option_id: 21 }
        ]
      )

      submit("1" => "10", "2" => %w[20 21])

      expect(response).to redirect_to(
        page_path(projekt.page.slug, projekt_phase_id: projekt_phase.id, anchor: "projekt-footer")
      )
      expect(flash_notice).to eq(I18n.t("custom.projekt_phases.mitmachbox_phase.thank_you"))
    end

    it "keeps only one option for a single_choice question" do
      expect(Mitmachbox::SubmitWebResponseService).to receive(:call)
        .with(hash_including(answers: [{ question_id: 1, option_id: 10 }]))

      submit("1" => %w[10 11])
    end

    it "drops an option that does not belong to the question" do
      expect(Mitmachbox::SubmitWebResponseService).to receive(:call)
        .with(hash_including(answers: [{ question_id: 1, option_id: 10 }]))

      submit("1" => "10", "2" => "999")
    end

    it "refuses a submission that skips a required question" do
      expect(Mitmachbox::SubmitWebResponseService).not_to receive(:call)

      submit("2" => "20")

      expect(flash_alert).to eq(I18n.t("custom.projekt_phases.mitmachbox_phase.missing_required"))
    end

    it "ignores a malformed answers payload instead of erroring" do
      malformed = [%w[10], { "1" => { "nested" => "10" }}, "junk", { "1" => [{ "a" => "10" }] }]

      malformed.each do |payload|
        expect(Mitmachbox::SubmitWebResponseService).not_to receive(:call)

        submit(payload)

        expect(response).to have_http_status(:found)
        expect(flash_alert).to be_present
      end
    end

    it "refuses an empty submission that skips a required question" do
      expect(Mitmachbox::SubmitWebResponseService).not_to receive(:call)

      submit({})

      expect(flash_alert).to eq(I18n.t("custom.projekt_phases.mitmachbox_phase.missing_required"))
    end

    it "refuses an empty submission when nothing is required" do
      survey["questions"].each { |question| question["required"] = false }
      expect(Mitmachbox::SubmitWebResponseService).not_to receive(:call)

      submit({})

      expect(flash_alert).to eq(I18n.t("custom.projekt_phases.mitmachbox_phase.no_answers"))
    end

    it "refuses a second submission for the same version" do
      MitmachboxParticipation.create!(projekt_phase: projekt_phase, user: user, survey_version_id: 42)
      expect(Mitmachbox::SubmitWebResponseService).not_to receive(:call)

      submit("1" => "10")

      expect(flash_notice).to eq(I18n.t("custom.projekt_phases.mitmachbox_phase.already_answered"))
    end

    it "allows a submission again once a new version is published" do
      MitmachboxParticipation.create!(projekt_phase: projekt_phase, user: user, survey_version_id: 41)
      expect(Mitmachbox::SubmitWebResponseService).to receive(:call)

      submit("1" => "10")
    end

    it "refuses a survey that is not open" do
      survey["state"] = "closed"
      expect(Mitmachbox::SubmitWebResponseService).not_to receive(:call)

      submit("1" => "10")

      expect(flash_alert).to eq(I18n.t("custom.projekt_phases.mitmachbox_phase.closed"))
    end

    it "reports a failure without recording anything when the platform is unreachable" do
      allow(Mitmachbox::SubmitWebResponseService).to receive(:call).and_raise(Mitmachbox::Error, "boom")

      submit("1" => "10")

      expect(flash_alert).to eq(I18n.t("custom.projekt_phases.mitmachbox_phase.submit_failed"))
      expect(MitmachboxParticipation.count).to eq(0)
    end

    it "honours a phase restriction" do
      projekt_phase.update!(user_status: "verified")
      expect(Mitmachbox::SubmitWebResponseService).not_to receive(:call)

      submit("1" => "10")

      expect(flash_alert).to eq(I18n.t("custom.projekt_phases.mitmachbox_phase.not_allowed"))
    end
  end

  context "when the phase allows guests" do
    before { projekt_phase.update!(user_status: "guest") }

    it "lets a guest submit" do
      guest = create(:user, guest: true)
      login_as(guest)

      expect(Mitmachbox::SubmitWebResponseService).to receive(:call)
        .with(hash_including(user: guest, survey_version_id: 42))

      submit("1" => "10")

      expect(flash_notice).to eq(I18n.t("custom.projekt_phases.mitmachbox_phase.thank_you"))
    end

    it "mints a guest for an anonymous visitor and accepts the submission" do
      submitted_user = nil
      allow(Mitmachbox::SubmitWebResponseService).to receive(:call) do |**kwargs|
        submitted_user = kwargs[:user]
        "created"
      end

      expect { submit("1" => "10") }.to change { User.where(guest: true).count }.by(1)

      expect(submitted_user).to eq(User.where(guest: true).last)
      expect(flash_notice).to eq(I18n.t("custom.projekt_phases.mitmachbox_phase.thank_you"))
    end

    it "reuses an established guest session instead of minting another" do
      allow(Mitmachbox::SubmitWebResponseService).to receive(:call)
      submit("1" => "10")

      expect { submit("2" => "20") }.not_to change { User.where(guest: true).count }
    end
  end

  it "refuses a signed-out visitor" do
    expect(Mitmachbox::SubmitWebResponseService).not_to receive(:call)

    submit("1" => "10")

    expect(flash_alert).to eq(I18n.t("custom.projekt_phases.mitmachbox_phase.not_allowed"))
  end
end
