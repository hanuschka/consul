require "rails_helper"

describe "Adm proposal official answer for projekt managers", type: :request do
  let(:projekt_phase) { create(:proposal_phase) }
  let(:projekt) { projekt_phase.projekt }
  let!(:proposal) { create(:proposal, projekt_phase: projekt_phase) }
  let(:show_path) { adm_projekts_phase_proposal_path(projekt_phase, proposal) }
  let(:answer_path) { update_official_answer_adm_projekts_phase_proposal_path(projekt_phase, proposal) }

  before do
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
    allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)
  end

  def sign_in_with(*permissions)
    manager = create(:projekt_manager)
    create(:projekt_manager_assignment, *permissions, projekt: projekt, projekt_manager: manager)
    login_as(manager.user)
  end

  def page
    Capybara.string(response.body)
  end

  def save_official_answer(text)
    patch answer_path, params: { proposal: { official_answer: text }}, as: :turbo_stream
  end

  context "with only 'approve'" do
    before { sign_in_with(:approve) }

    it "shows an enabled official answer editor" do
      get show_path

      expect(page).to have_css("form[action='#{answer_path}'] textarea:not([disabled])")
      expect(page).not_to have_text(I18n.t("adm.not_authorized_edit"))
    end

    it "keeps the editor enabled after saving" do
      save_official_answer("<p>Wird umgesetzt</p>")

      expect(response.body).to include("action=\"#{answer_path}\"")
      expect(response.body).not_to match(/<textarea[^>]*disabled/)
    end

    it "saves the official answer and shows it on the public proposal page" do
      save_official_answer("<p>Wird umgesetzt</p>")

      expect(proposal.reload.official_answer).to eq("<p>Wird umgesetzt</p>")

      get proposal_path(proposal)

      expect(page).to have_text("Wird umgesetzt")
    end

    it "emails the author when the official answer email is switched on" do
      Setting["proposals.email_on_official_answer"] = true

      expect { save_official_answer("<p>Wird umgesetzt</p>") }
        .to have_enqueued_mail(Mailer, :proposal_official_answer)
    end
  end

  context "with only 'moderate'" do
    before { sign_in_with(:moderate) }

    it "shows no official answer section when there is no answer" do
      get show_path

      expect(response).to have_http_status(:ok)
      expect(page).not_to have_text(I18n.t("adm.projekts.proposals.show.official_answer"))
    end

    it "shows a saved official answer read-only" do
      proposal.update!(official_answer: "<p>Wird umgesetzt</p>")

      get show_path

      expect(page).to have_text("Wird umgesetzt")
      expect(page).not_to have_css("form[action='#{answer_path}']")
    end

    it "is refused saving an official answer" do
      save_official_answer("<p>Wird umgesetzt</p>")

      expect(proposal.reload.official_answer).to be_blank
    end
  end
end
