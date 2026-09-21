require "rails_helper"

describe "Vorhaben in /adm", type: :request do
  let(:admin) { create(:administrator).user }
  let(:officer) { create(:municipal_plan_officer) }
  let(:district) { create(:registered_address_district) }
  let(:other_district) { create(:registered_address_district) }
  let(:topic) { create(:municipal_plan_topic) }
  let(:plan) { create(:municipal_plan, responsible: officer) }

  before do
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
    allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)
    login_as(admin)
  end

  def patch_plan(attributes)
    patch adm_municipal_plans_municipal_plan_path(plan), params: { municipal_plan: attributes }
  end

  describe "the Versionsnummer when a case worker saves" do
    it "stays put on a save that changes nothing" do
      expect { patch_plan(district_ids: plan.district_ids, topic_ids: plan.topic_ids) }
        .not_to change { plan.reload.version }
    end

    it "advances once when only the Ortsteile change" do
      expect { patch_plan(district_ids: plan.district_ids + [other_district.id]) }
        .to change { plan.reload.version }.from("0.1").to("0.2")
    end

    it "advances once when only the Themen change" do
      expect { patch_plan(topic_ids: plan.topic_ids + [topic.id]) }
        .to change { plan.reload.version }.from("0.1").to("0.2")
    end

    it "advances only once when an attribute and an association change together" do
      expect do
        patch_plan(contact_name: "Kai Ostermann", district_ids: plan.district_ids + [other_district.id])
      end.to change { plan.reload.version }.from("0.1").to("0.2")
    end

    it "stays put when unchanged links are resubmitted" do
      link = plan.links.create!(title: "Rahmenplan", url: "https://example.org", given_order: 1)

      expect do
        patch_plan(links_attributes: { "0" => { id: link.id, title: link.title, url: link.url,
                                                given_order: link.given_order }})
      end.not_to change { plan.reload.version }
    end

    it "advances once when a link is edited" do
      link = plan.links.create!(title: "Rahmenplan", url: "https://example.org", given_order: 1)

      expect do
        patch_plan(links_attributes: { "0" => { id: link.id, title: "Rahmenplan 2025",
                                                url: link.url, given_order: link.given_order }})
      end.to change { plan.reload.version }.from("0.1").to("0.2")
    end

    it "moves to 1.0 when the plan is published" do
      expect { patch_plan(status: "published") }
        .to change { plan.reload.version }.from("0.1").to("1.0")
    end

    it "stays put on a later status change" do
      plan.update!(status: "published")

      expect { patch_plan(status: "archived") }.not_to change { plan.reload.version }
    end
  end
end
