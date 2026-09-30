require "rails_helper"

describe Adm::HintComponent, type: :component, controller: Adm::BaseController do
  def sign_in(user)
    allow(vc_test_controller).to receive(:current_user).and_return(user)
  end

  def render_hint
    render_inline(Adm::HintComponent.new) { "Erklärung" }
  end

  it "points the toggle at its own panel" do
    render_hint

    panel_id = page.find(".adm-hint__panel", visible: :all)[:id]

    expect(page.find(".adm-hint__toggle")["aria-controls"]).to eq(panel_id)
  end

  it "gives every hint on a page its own panel id" do
    first_id = render_hint.at_css(".adm-hint__panel")[:id]
    second_id = render_hint.at_css(".adm-hint__panel")[:id]

    expect(first_id).not_to eq(second_id)
  end
end
