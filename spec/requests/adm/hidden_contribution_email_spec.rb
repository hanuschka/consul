require "rails_helper"

describe "Hiding contributions in /adm", type: :request do
  let(:admin) { create(:administrator).user }

  before do
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
    allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)
    login_as(admin)
  end

  def hide
    turbo_put hide_path
  end

  def turbo_put(path)
    put path, headers: { "Accept" => "text/vnd.turbo-stream.html" }
  end

  shared_examples "tells the author" do
    it "sends the hidden email to the author" do
      expect { hide }.to have_enqueued_mail(Mailer, :resource_hidden).with(resource)

      expect(resource.reload).to be_hidden
    end

    it "sends nothing to an author without email" do
      resource.author.update_column(:email, nil)

      expect { hide }.not_to have_enqueued_mail

      expect(response).to be_successful
      expect(resource.reload).to be_hidden
    end
  end

  shared_examples "tells the author only once" do
    it "sends nothing when the contribution is already hidden" do
      resource.hide

      expect { hide }.not_to have_enqueued_mail
    end
  end

  context "in the moderation area" do
    context "for a proposal" do
      let(:resource) { create(:proposal) }
      let(:hide_path) { hide_adm_moderation_proposal_path(resource) }

      it_behaves_like "tells the author"
    end

    context "for a comment" do
      let(:resource) { create(:comment) }
      let(:hide_path) { hide_adm_moderation_comment_path(resource) }

      it_behaves_like "tells the author"

      it "sends nothing when the comment is restored" do
        resource.hide

        expect { turbo_put unhide_adm_moderation_comment_path(resource) }.not_to have_enqueued_mail
      end
    end

    context "for a budget proposal" do
      let(:resource) { create(:budget_investment) }
      let(:hide_path) { hide_adm_moderation_budget_investment_path(resource) }

      it_behaves_like "tells the author"
    end
  end

  context "in the project view" do
    context "for a proposal" do
      let(:resource) { create(:proposal) }
      let(:hide_path) { hide_adm_projekts_phase_proposal_path(resource.projekt_phase, resource) }

      it_behaves_like "tells the author"
      it_behaves_like "tells the author only once"
    end

    context "for a comment" do
      let(:resource) { create(:comment) }
      let(:hide_path) { hide_adm_projekts_phase_comment_path(resource.commentable, resource) }

      it_behaves_like "tells the author"
      it_behaves_like "tells the author only once"
    end

    context "for a budget proposal" do
      let(:resource) { create(:budget_investment) }
      let(:hide_path) do
        hide_adm_projekts_phase_budget_investment_path(resource.budget.projekt_phase, resource)
      end

      it_behaves_like "tells the author"
    end
  end
end
