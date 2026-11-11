require "rails_helper"

describe LinksHelper do
  describe "#link_to_sms_signin" do
    it "returns nothing while SMS sign-in is off" do
      set_setting("extended_feature.general.sms_login", false)

      expect(helper.link_to_sms_signin).to be_nil
    end

    it "links to the SMS sign-in page while SMS sign-in is on" do
      set_setting("extended_feature.general.sms_login", true)

      expect(helper.link_to_sms_signin).to include(%(href="#{new_sms_sign_in_path}"))
    end

    it "passes the intended path on" do
      set_setting("extended_feature.general.sms_login", true)

      link = helper.link_to_sms_signin(intended_path: "/proposals/new", class: "probe")

      expect(link).to include(new_sms_sign_in_path(intended_path: "/proposals/new"))
      expect(link).to include('class="probe js-sms-sign-in"')
    end
  end
end
