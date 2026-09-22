require "rails_helper"

describe MunicipalPlans::WorkingCopyService do
  let(:officer) { create(:municipal_plan_officer) }
  let(:district) { create(:registered_address_district) }
  let(:topic) { create(:municipal_plan_topic) }
  let(:plan) do
    create(:municipal_plan, :published, responsible: officer,
                                        title: "Sanierung der Brücke",
                                        short_description: "Die Brücke wird saniert.",
                                        contact_name: "Kai Ostermann")
  end

  it "carries the content of the released Vorhaben" do
    copy = MunicipalPlans::WorkingCopyService.call(plan)

    expect(copy.title).to eq("Sanierung der Brücke")
    expect(copy.short_description).to eq("Die Brücke wird saniert.")
    expect(copy.contact_name).to eq("Kai Ostermann")
    expect(copy.responsible).to eq(officer)
  end

  it "carries Ortsteile, Themen, Links and the Kartenposition" do
    plan.district_ids = [district.id]
    plan.topic_ids = [topic.id]
    plan.links.create!(title: "Rahmenplan", url: "https://example.org", given_order: 1)

    copy = MunicipalPlans::WorkingCopyService.call(plan.reload)

    expect(copy.district_ids).to match_array([district.id])
    expect(copy.topic_ids).to match_array([topic.id])
    expect(copy.links.map(&:title)).to eq(["Rahmenplan"])
    expect(copy.map_location).to be_present
    expect(copy.map_location.id).not_to eq(plan.map_location.id)
  end

  it "stays an Entwurf nobody has handed in yet" do
    copy = MunicipalPlans::WorkingCopyService.call(plan)

    expect(copy).to be_draft
    expect(copy).to be_working_copy
    expect(copy).not_to be_submitted_for_release
    expect(copy.released_plan).to eq(plan)
  end

  it "keeps the copy out of the public list" do
    copy = MunicipalPlans::WorkingCopyService.call(plan)

    expect(MunicipalPlan.published).to include(plan)
    expect(MunicipalPlan.published).not_to include(copy)
  end

  it "leaves the released Vorhaben untouched" do
    before_release = plan.attributes.slice("version", "content_updated_at", "status")

    MunicipalPlans::WorkingCopyService.call(plan)

    expect(plan.reload.attributes.slice("version", "content_updated_at", "status"))
      .to eq(before_release)
  end

  it "hands back the same copy on a second call" do
    copy = MunicipalPlans::WorkingCopyService.call(plan)

    expect { MunicipalPlans::WorkingCopyService.call(plan.reload) }.not_to change(MunicipalPlan, :count)
    expect(MunicipalPlans::WorkingCopyService.call(plan.reload)).to eq(copy)
  end

  it "hands back the record itself when it is already a working copy" do
    copy = MunicipalPlans::WorkingCopyService.call(plan)

    expect(MunicipalPlans::WorkingCopyService.call(copy)).to eq(copy)
  end

  it "refuses a working copy of a working copy" do
    copy = MunicipalPlans::WorkingCopyService.call(plan)
    nested = MunicipalPlan.new(title: "Noch eine Fassung", released_plan: copy)

    expect(nested).not_to be_valid
    expect(nested.errors[:base])
      .to include(I18n.t("activerecord.errors.models.municipal_plan.nested_working_copy"))
  end

  it "lets the copy be saved while it is still incomplete" do
    copy = MunicipalPlans::WorkingCopyService.call(plan)
    copy.short_description = ""

    expect(copy).to be_valid
  end
end
