require "rails_helper"

describe MunicipalPlans::ChangeSummaryService do
  let(:officer) { create(:municipal_plan_officer) }
  let(:district) { create(:registered_address_district) }
  let(:topic) { create(:municipal_plan_topic) }
  let(:plan) do
    create(:municipal_plan, :published, responsible: officer,
                                        short_description: "Alte Fassung",
                                        contact_name: "Kai Ostermann")
  end
  let(:copy) { MunicipalPlans::WorkingCopyService.call(plan) }

  def change_for(field)
    MunicipalPlans::ChangeSummaryService.call(copy).find { |change| change.field == field }
  end

  it "reports nothing while the copy is untouched" do
    expect(MunicipalPlans::ChangeSummaryService.call(copy)).to be_empty
  end

  it "reports nothing for a Vorhaben that is not a working copy" do
    expect(MunicipalPlans::ChangeSummaryService.call(plan)).to be_empty
  end

  it "reports a changed text with both sides and the field label" do
    copy.update!(short_description: "Neue Fassung")

    change = change_for("short_description")

    expect(change.before).to eq("Alte Fassung")
    expect(change.after).to eq("Neue Fassung")
    expect(change.kind).to eq(:rich_text)
    expect(change.label).to eq(MunicipalPlan.human_attribute_name(:short_description))
  end

  it "reports a changed Kontakt field as plain text" do
    copy.update!(contact_name: "Lena Wolf")

    expect(change_for("contact_name").kind).to eq(:text)
    expect(change_for("contact_name").after).to eq("Lena Wolf")
  end

  it "reports a Beteiligung flag as a boolean" do
    copy.update!(formal_participation: !plan.formal_participation)

    expect(change_for("formal_participation").kind).to eq(:boolean)
  end

  it "reports changed Ortsteile and Themen as lists" do
    copy.district_ids = [district.id]
    copy.topic_ids = [topic.id]

    expect(change_for("districts").kind).to eq(:list)
    expect(change_for("districts").after).to eq([district.name_for_display])
    expect(change_for("topics").after).to eq([topic.name])
  end

  it "reports an added Link" do
    copy.links.create!(title: "Rahmenplan", url: "https://example.org", given_order: 1)

    expect(change_for("links").before).to eq([])
    expect(change_for("links").after).to eq(["Rahmenplan (https://example.org)"])
  end

  it "reports a moved Kartenposition" do
    copy.map_location.update!(latitude: 50.9, longitude: 11.6)

    expect(change_for("map_location").kind).to eq(:map)
  end

  it "reports a changed Zuständigkeit" do
    other = create(:municipal_plan_officer)
    copy.update!(responsible: other)

    expect(change_for("responsible").before).to eq(officer.name)
    expect(change_for("responsible").after).to eq(other.name)
  end

  it "leaves the workflow fields out" do
    copy.update!(given_order: 7)

    expect(MunicipalPlans::ChangeSummaryService.call(copy).map(&:field))
      .not_to include("given_order", "status", "version", "content_updated_at")
  end
end
