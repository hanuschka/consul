require "rails_helper"

describe Adm::RecipientGroupFilterCardComponent, type: :component, controller: Adm::BaseController do
  # Override `sign_in` to use vc_test_controller (view_component 3.x changed the API,
  # but the project's rails_helper monkey-patch still references `controller`).
  def sign_in(user)
    allow(vc_test_controller).to receive(:current_user).and_return(user)
  end

  let(:group) { create(:recipient_group) }
  let(:filter) do
    create(:recipient_group_filter,
           recipient_group: group,
           position: 1,
           kind: "newsletter_subscribers",
           operator: "include")
  end

  it "renders the kind label" do
    render_inline(described_class.new(filter: filter, count: 42))

    expect(page).to have_text(I18n.t("adm.recipient_groups.filters.kinds.newsletter_subscribers"))
  end

  it "hides operator select on first filter" do
    render_inline(described_class.new(filter: filter, count: 0))

    expect(page).not_to have_select("recipient_group_filter[operator]")
  end

  it "shows operator select on second filter" do
    create(:recipient_group_filter, recipient_group: group, position: 1, operator: "include")
    second = create(:recipient_group_filter,
                    recipient_group: group,
                    position: 2,
                    operator: "include",
                    kind: "newsletter_subscribers")

    render_inline(described_class.new(filter: second, count: 5))

    expect(page).to have_select("recipient_group_filter[operator]")
  end

  it "shows positive delta" do
    render_inline(described_class.new(filter: filter, count: 50, delta: 10))

    expect(page).to have_text(I18n.t("adm.recipient_groups.filters.counter.delta_plus", count: 10))
  end

  it "shows negative delta" do
    render_inline(described_class.new(filter: filter, count: 5, delta: -3))

    expect(page).to have_text(I18n.t("adm.recipient_groups.filters.counter.delta_minus", count: 3))
  end
end
