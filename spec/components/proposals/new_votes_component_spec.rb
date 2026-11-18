require "rails_helper"

describe Proposals::NewVotesComponent, type: :component do
  let(:proposal) { create(:proposal) }

  before do
    allow(vc_test_controller).to receive(:current_user).and_return(nil)
    allow_any_instance_of(Proposals::NewVotesComponent).to receive(:projekt_phase_feature?).and_return(true)
    allow_any_instance_of(ProjektPhase).to receive(:permission_problem).and_return(:not_logged_in)
  end

  it "offers SMS sign-in to signed-out visitors while SMS sign-in is on" do
    set_setting("extended_feature.general.sms_login", true)

    render_inline(Proposals::NewVotesComponent.new(proposal))

    expect(page).to have_link(I18n.t("sms_sign_in.hint.link"), href: "/users/sms_sign_in")
  end

  it "does not offer SMS sign-in while SMS sign-in is off" do
    set_setting("extended_feature.general.sms_login", false)

    render_inline(Proposals::NewVotesComponent.new(proposal))

    expect(page).not_to have_link(I18n.t("sms_sign_in.hint.link"))
  end
end
