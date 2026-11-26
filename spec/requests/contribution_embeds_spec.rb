require "rails_helper"

describe "External content in submitted descriptions", type: :request do
  let(:description) do
    '<p>Mehr Bänke</p><iframe src="https://example.org/page"></iframe>' \
      '<img src="https://example.org/pixel.png">'
  end

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
          "0" => { locale: I18n.default_locale, title: "Mehr Bänke im Stadtpark",
                   description: description }
        }
      }
    }
  end

  before do
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
    allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)
    InvisibleCaptcha.timestamp_enabled = false
  end

  after { InvisibleCaptcha.timestamp_enabled = true }

  it "is removed when a citizen submits it" do
    login_as(create(:user))

    post proposals_path, params: proposal_params

    expect(Proposal.last.description).to eq "<p>Mehr Bänke</p>"
  end

  it "is kept when an administrator submits it" do
    login_as(create(:administrator).user)

    post proposals_path, params: proposal_params

    expect(Proposal.last.description).to eq description
  end

  it "does not reach the detail page of a budget investment a citizen submits" do
    budget = create(:budget, :with_heading, :accepting_now)
    ProjektPhaseSetting.create!(projekt_phase: budget.projekt_phase,
                                key: "feature.resource.users_can_create_investment_proposals",
                                value: "active")
    login_as(create(:user))

    post budget_investments_path(budget), params: {
      budget_investment: {
        resource_terms: "1",
        translations_attributes: {
          "0" => { locale: I18n.default_locale, title: "Eine Bank am Fluss", description: description }
        }
      }
    }
    get budget_investment_path(budget, Budget::Investment.last)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Mehr Bänke")
    expect(response.body).not_to include("example.org/page", "example.org/pixel.png")
  end

  describe "embeds behind the consent overlay" do
    before { Setting["extended_feature.gdpr.two_click_iframe_solution"] = true }

    it "hands the video of the video link field to the consent overlay" do
      proposal = create(:proposal, video_url: "https://www.youtube.com/watch?v=abc123")

      get proposal_path(proposal)

      player = Nokogiri::HTML(response.body).at_css("iframe.external-video-player")
      expect(player["data-src"]).to include("abc123")
      expect(player["src"]).to be_blank
    end

    it "keeps the frame of an admin content block behind the consent overlay" do
      SiteCustomization::ContentBlock.custom_block_for("budget_investment_show_welcome_text")
        .update!(body: '<p>Willkommen</p><iframe src="https://www.youtube.com/embed/abc123"></iframe>')
      investment = create(:budget_investment)
      investment.budget.update_column(:published, true)

      get budget_investment_path(investment.budget, investment)

      expect(response.body).to include('data-src="https://www.youtube.com/embed/abc123"')
      expect(response.body).not_to match(%r{<iframe[^>]* src="https://www\.youtube\.com})
    end
  end

  describe "rendering an embed in a description" do
    let(:frame) { '<iframe src="https://www.youtube.com/embed/abc123"></iframe>' }

    it "waits for consent when two-click embeds are switched on" do
      Setting["extended_feature.gdpr.two_click_iframe_solution"] = true
      proposal = create(:proposal, description: "<p>Video</p>#{frame}")

      get proposal_path(proposal)

      expect(response.body).to include('data-src="https://www.youtube.com/embed/abc123"')
      expect(response.body).not_to match(%r{<iframe[^>]* src="https://www\.youtube\.com})
    end

    it "loads at once when two-click embeds are switched off" do
      Setting["extended_feature.gdpr.two_click_iframe_solution"] = nil
      proposal = create(:proposal, description: "<p>Video</p>#{frame}")

      get proposal_path(proposal)

      expect(response.body).to match(%r{<iframe[^>]* src="https://www\.youtube\.com/embed/abc123"})
    end

    it "does not break an e-mail that shows the text" do
      Setting["extended_feature.gdpr.two_click_iframe_solution"] = true
      proposal = create(:proposal, official_answer: "<p>Antwort</p>#{frame}")

      expect { Mailer.proposal_official_answer(proposal).deliver_now }.not_to raise_error
    end
  end
end
