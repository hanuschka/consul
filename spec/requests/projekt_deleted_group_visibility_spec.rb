require "rails_helper"

describe "A group-restricted projekt after one of its groups is deleted", type: :request do
  let(:group_a) { create(:individual_group, kind: "hard") }
  let(:group_b) { create(:individual_group, kind: "hard") }
  let(:projekt) { create(:projekt, name: "Vorschläge 2026") }
  let(:forbidden_title) { "Error 403 | Forbidden" }

  before do
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
    allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)

    projekt.individual_group_values << [create(:individual_group_value, individual_group: group_a),
                                        create(:individual_group_value, individual_group: group_b)]
    group_a.destroy!
  end

  it "shows logged-out visitors the forbidden page" do
    get page_path(projekt.page.slug)

    expect(response.body).to include(forbidden_title)
  end

  it "leaves the projekt out of the overview for logged-out visitors" do
    unrestricted = create(:projekt, name: "Offenes Projekt")

    get projekts_path(order: "index_order_all")

    expect(response.body).to include(unrestricted.page.title)
    expect(response.body).not_to include(projekt.page.title)
  end
end
