require "rails_helper"

describe Adm::DeficiencyReports::IntakeChannelsController do
  let(:manager) { create(:user).tap { |user| DeficiencyReportManager.create!(user: user) } }

  context "as a deficiency report manager" do
    before { sign_in manager }

    describe "GET #index" do
      it "responds successfully" do
        create(:deficiency_report_intake_channel)

        get :index

        expect(response).to have_http_status(:ok)
      end
    end

    describe "POST #create" do
      it "creates a channel" do
        expect do
          post :create, params: { deficiency_report_intake_channel: { name: "Telefon" }}
        end.to change(DeficiencyReport::IntakeChannel, :count).by(1)

        expect(response).to redirect_to(adm_deficiency_reports_intake_channels_path)
        expect(DeficiencyReport::IntakeChannel.last.name).to eq("Telefon")
      end

      it "creates a channel marked as the default" do
        post :create, params: { deficiency_report_intake_channel: { name: "Platform", default: "1" }}

        expect(DeficiencyReport::IntakeChannel.last.default).to be(true)
      end

      it "re-renders the form when the name is missing" do
        expect do
          post :create, params: { deficiency_report_intake_channel: { name: "" }}
        end.not_to change(DeficiencyReport::IntakeChannel, :count)

        # A re-render answers 200, where a successful create redirects.
        expect(response).to have_http_status(:ok)
      end
    end

    describe "PATCH #update" do
      let(:channel) { create(:deficiency_report_intake_channel, name: "Telefon") }

      it "renames the channel" do
        patch :update, params: { id: channel.id,
                                 deficiency_report_intake_channel: { name: "E-Mail" }}

        expect(channel.reload.name).to eq("E-Mail")
        expect(response).to redirect_to(adm_deficiency_reports_intake_channels_path)
      end

      it "moves the default flag off the previous default" do
        old_default = create(:deficiency_report_intake_channel, default: true)

        patch :update, params: { id: channel.id,
                                 deficiency_report_intake_channel: { name: "Telefon", default: "1" }}

        expect(channel.reload.default).to be(true)
        expect(old_default.reload.default).to be(false)
      end

      it "re-renders the form when the name is cleared" do
        patch :update, params: { id: channel.id, deficiency_report_intake_channel: { name: "" }}

        expect(response).to have_http_status(:ok)
        expect(channel.reload.name).to eq("Telefon")
      end
    end

    describe "DELETE #destroy" do
      it "deletes an unused channel" do
        channel = create(:deficiency_report_intake_channel)

        expect do
          delete :destroy, params: { id: channel.id }
        end.to change(DeficiencyReport::IntakeChannel, :count).by(-1)

        expect(flash[:notice]).to be_present
      end

      # Reports keep pointing at their channel, so one in use must survive with an explanation.
      it "refuses to delete a channel a report still uses" do
        channel = create(:deficiency_report_intake_channel)
        create(:deficiency_report, intake_channel: channel)

        expect do
          delete :destroy, params: { id: channel.id }
        end.not_to change(DeficiencyReport::IntakeChannel, :count)

        expect(flash[:alert]).to be_present
      end
    end

    describe "PATCH #order_intake_channels" do
      it "renumbers the channels from the submitted tree" do
        first = create(:deficiency_report_intake_channel, given_order: 1)
        second = create(:deficiency_report_intake_channel, given_order: 2)

        patch :order_intake_channels, params: { tree: [{ id: second.id }, { id: first.id }] }

        expect(response).to have_http_status(:ok)
        expect(second.reload.given_order).to eq(1)
        expect(first.reload.given_order).to eq(2)
      end
    end
  end

  context "as an officer without manage_all" do
    let(:officer) { create(:deficiency_report_officer) }

    before { sign_in officer.user }

    # policy_scope alone does not gate the action — its Scope resolves to all — so index has to
    # authorize as well, or the configuration list is readable by any officer.
    it "refuses to read the channel list" do
      get :index

      expect(response).to redirect_to(adm_deficiency_reports_root_path)
      expect(flash[:alert]).to be_present
    end

    it "refuses to open the new-channel form" do
      get :new

      expect(response).to redirect_to(adm_deficiency_reports_root_path)
      expect(flash[:alert]).to be_present
    end

    it "refuses to create a channel" do
      expect do
        post :create, params: { deficiency_report_intake_channel: { name: "Telefon" }}
      end.not_to change(DeficiencyReport::IntakeChannel, :count)

      expect(response).to redirect_to(adm_deficiency_reports_root_path)
    end
  end
end
