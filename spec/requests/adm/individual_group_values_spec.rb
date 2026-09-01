require "rails_helper"

describe "Individual group values in /adm", type: :request do
  let(:admin) { create(:administrator).user }
  let(:group_value) { create(:individual_group_value) }
  let(:individual_group) { group_value.individual_group }

  before do
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
    allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)
    login_as(admin)
  end

  def add_email(email)
    post add_email_adm_individual_group_value_path(individual_group, group_value, email: email)
  end

  describe "adding an address without an account" do
    it "accepts it instead of failing" do
      add_email("ohnekonto@example.org")

      expect(response).to redirect_to(adm_individual_group_value_path(individual_group, group_value))
      expect(group_value.reload.auto_join_emails).to eq(["ohnekonto@example.org"])
    end

    it "rejects an address that is not valid" do
      add_email("kein-email")

      expect(flash[:alert]).to eq(I18n.t("adm.individual_group_values.add_email.invalid"))
      expect(group_value.reload.auto_join_emails).to be_empty
    end

    it "creates no second entry for an address already stored" do
      add_email("doppelt@example.org")

      expect { add_email("doppelt@example.org") }
        .not_to change { group_value.reload.auto_join_emails.size }

      expect(flash[:notice]).to eq(I18n.t("adm.individual_group_values.add_email.already_stored"))
    end

    it "lists it on the page as not yet registered" do
      add_email("gelistet@example.org")

      get adm_individual_group_value_path(individual_group, group_value)

      expect(response.body).to include("gelistet@example.org")
    end

    it "can be removed again" do
      add_email("wegdamit@example.org")

      delete remove_email_from_auto_join_emails_adm_individual_group_value_path(
        individual_group, group_value, email: "wegdamit@example.org"
      )

      expect(group_value.reload.auto_join_emails).to be_empty
    end
  end

  describe "adding an existing user twice" do
    it "creates only one membership" do
      user = create(:user)
      post add_user_adm_individual_group_value_path(individual_group, group_value, user_id: user.id)

      expect {
        post add_user_adm_individual_group_value_path(individual_group, group_value, user_id: user.id)
      }.not_to change { UserIndividualGroupValue.where(individual_group_value: group_value).count }
    end
  end

  describe "permissions" do
    it "denies a regular user" do
      login_as(create(:user))

      add_email("fremd@example.org")

      expect(group_value.reload.auto_join_emails).to be_empty
    end
  end
end
