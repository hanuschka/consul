require "rails_helper"

describe Adm::RecipientGroupFiltersController do
  let(:admin) { create(:administrator, user: create(:user, password: "Password1!")).user }
  let(:group) { create(:recipient_group) }

  before { sign_in admin }

  describe "POST #create" do
    it "creates a filter and responds with turbo_stream" do
      post :create,
           params: { recipient_group_id: group.id,
                     recipient_group_filter: { kind: "newsletter_subscribers", operator: "include", params: {} } },
           format: :turbo_stream

      expect(response).to have_http_status(:ok)
      expect(group.reload.filters.size).to eq(1)
    end
  end

  describe "PATCH #update" do
    let!(:filter) { create(:recipient_group_filter, recipient_group: group) }

    it "updates params" do
      patch :update,
            params: { recipient_group_id: group.id, id: filter.id,
                      recipient_group_filter: { params: { "include_unregistered" => true } } },
            format: :turbo_stream

      expect(filter.reload.params).to eq("include_unregistered" => "true")
    end
  end

  describe "DELETE #destroy" do
    let!(:filter) { create(:recipient_group_filter, recipient_group: group) }

    it "destroys the filter" do
      expect {
        delete :destroy, params: { recipient_group_id: group.id, id: filter.id }, format: :turbo_stream
      }.to change(RecipientGroupFilter, :count).by(-1)
    end
  end

  describe "POST #reorder" do
    let!(:f1) { create(:recipient_group_filter, recipient_group: group, position: 1) }
    let!(:f2) { create(:recipient_group_filter, recipient_group: group, position: 2) }

    it "applies the given order" do
      post :reorder,
           params: { recipient_group_id: group.id, ordered_ids: [f2.id, f1.id] },
           format: :turbo_stream

      expect(f1.reload.position).to eq(2)
      expect(f2.reload.position).to eq(1)
    end
  end

  describe "GET #recount" do
    it "responds with turbo_stream containing the counter" do
      create(:recipient_group_filter, recipient_group: group)
      get :recount, params: { recipient_group_id: group.id }, format: :turbo_stream
      expect(response).to have_http_status(:ok)
    end
  end
end
