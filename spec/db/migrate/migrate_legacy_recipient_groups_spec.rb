require "rails_helper"
require Rails.root.join("db/migrate").glob("*migrate_legacy_recipient_groups*.rb").first

describe MigrateLegacyRecipientGroups do
  before do
    RecipientGroupFilter.delete_all
    RecipientGroup.delete_all
  end

  it "migrates a newsletter_subscriber_ids group" do
    rg = RecipientGroup.create!(name: "All subs",
                                origin_class_name: "User",
                                access_method: "newsletter_subscriber_ids")
    described_class.new.up
    rg.reload
    expect(rg.filters.size).to eq(1)
    expect(rg.filters.first.kind).to eq("newsletter_subscribers")
    expect(rg.filters.first.params).to eq("include_unregistered" => false)
  end

  it "migrates an all_newsletter_subscriber_ids group" do
    rg = RecipientGroup.create!(name: "All+", origin_class_name: "User",
                                access_method: "all_newsletter_subscriber_ids")
    described_class.new.up
    expect(rg.reload.filters.first.params).to eq("include_unregistered" => true)
  end

  it "migrates an administrators_ids group" do
    rg = RecipientGroup.create!(name: "Admins", origin_class_name: "User",
                                access_method: "administrators_ids")
    described_class.new.up
    f = rg.reload.filters.first
    expect(f.kind).to eq("role")
    expect(f.params).to eq("role" => "administrator")
  end

  it "migrates a projekt-related any_phase_subscribers_ids group" do
    projekt = create(:projekt)
    rg = RecipientGroup.create!(name: "Phase subs", origin_class_name: "Projekt",
                                origin_class_object_id: projekt.id.to_s,
                                access_method: "any_phase_subscribers_ids")
    described_class.new.up
    f = rg.reload.filters.first
    expect(f.kind).to eq("phase_subscribers")
    expect(f.params).to eq("projekt_id" => projekt.id)
  end

  it "migrates a BudgetPhase authors_of_winners_ids group" do
    phase = create(:projekt_phase, :budget_phase)
    rg = RecipientGroup.create!(name: "Winners", origin_class_name: "ProjektPhase",
                                origin_class_object_id: phase.id.to_s,
                                access_method: "authors_of_winners_ids")
    described_class.new.up
    f = rg.reload.filters.first
    expect(f.kind).to eq("phase_authors")
    expect(f.params).to eq("projekt_phase_id" => phase.id, "criterion" => "winners")
  end

  it "is idempotent — running twice does not duplicate filters" do
    rg = RecipientGroup.create!(name: "X", origin_class_name: "User",
                                access_method: "administrators_ids")
    described_class.new.up
    described_class.new.up
    expect(rg.reload.filters.size).to eq(1)
  end
end
