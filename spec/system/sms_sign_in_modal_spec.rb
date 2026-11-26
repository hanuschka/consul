require "rails_helper"

describe "Signing in with an SMS code in the modal", type: :system do
  let(:proposal) { create(:proposal) }

  around do |example|
    ActionController::Base.allow_forgery_protection = true
    example.run
  ensure
    ActionController::Base.allow_forgery_protection = false
  end

  before do
    set_setting("extended_feature.general.sms_login", true)
    Sms::Adapters::Log.deliveries.clear

    phase = proposal.projekt_phase
    phase.update!(active: true, start_date: 1.day.ago, end_date: 1.day.from_now)
    phase.projekt.update!(activated: true)
    ProjektPhaseSetting.create!(projekt_phase: phase, key: "feature.resource.show_comments", value: "active")
  end

  it "signs the visitor in and stays on the page" do
    visit proposal_path(proposal)

    within(".callout.alert") { click_link I18n.t("sms_sign_in.hint.link") }

    within("#sms-sign-in-modal") do
      fill_in I18n.t("sms_sign_in.new.phone_label"), with: "0171 1234567"
      click_button I18n.t("sms_sign_in.new.submit")

      expect(page).to have_field(I18n.t("sms_sign_in.edit.code_label"))
      code = Sms::Adapters::Log.deliveries.last[:text][/\b\d{6}\b/]
      fill_in I18n.t("sms_sign_in.edit.code_label"), with: code
      click_button I18n.t("sms_sign_in.edit.submit")
    end

    expect(page).not_to have_link(I18n.t("sms_sign_in.hint.link"))
    expect(page).to have_current_path(proposal_path(proposal))
    expect(User.find_by(confirmed_phone: "+491711234567")).to be_present
  end
end
