require "rails_helper"

describe Adm::MunicipalPlansQuery do
  let(:officer) { create(:municipal_plan_officer) }
  let(:group) { create(:municipal_plan_officer_group) }

  let!(:draft) do
    create(:municipal_plan, responsible: officer, title: "Entwurf Brücke", status: "draft")
  end
  let!(:published) do
    create(:municipal_plan, responsible: group, title: "Publiziert Platz", status: "published")
  end
  let!(:archived) do
    create(:municipal_plan, responsible: officer, title: "Archiv Schule", status: "archived")
  end

  def resolve(attributes)
    described_class.new(
      MunicipalPlan.all, ActionController::Parameters.new(attributes).permit!
    ).call
  end

  describe "Status" do
    it "filters to one status" do
      expect(resolve("status" => ["draft"])).to match_array([draft])
    end

    it "widens across several statuses" do
      expect(resolve("status" => %w[draft archived])).to match_array([draft, archived])
    end

    it "ignores an unknown status" do
      expect(resolve("status" => ["sideways"])).to match_array([draft, published, archived])
    end
  end

  describe "Zuständigkeit" do
    it "filters to a Bearbeitergruppe" do
      expect(resolve("responsible" => ["OfficerGroup:#{group.id}"])).to match_array([published])
    end

    it "filters to a Sachbearbeitung" do
      expect(resolve("responsible" => ["Officer:#{officer.id}"])).to match_array([draft, archived])
    end

    it "ignores a tampered responsible type" do
      expect(resolve("responsible" => ["User:1"])).to match_array([draft, published, archived])
    end
  end

  describe "combining Status with Zuständigkeit" do
    it "narrows across the two filters" do
      result = resolve("status" => ["draft"], "responsible" => ["Officer:#{officer.id}"])

      expect(result).to match_array([draft])
    end
  end

  describe "title search" do
    it "matches part of a title, case-insensitively" do
      expect(resolve("title__search" => "brücke")).to match_array([draft])
    end

    it "survives being combined with sorting" do
      result = resolve("title__search" => "e", "sort_by" => "status", "sort_direction" => "desc")

      expect(result.map(&:title)).to include("Entwurf Brücke")
    end
  end

  describe "sorting" do
    it "falls back to the editorial order for an unknown field" do
      draft.update!(given_order: 1)
      published.update!(given_order: 2)
      archived.update!(given_order: 3)

      expect(resolve("sort_by" => "internal_notes").to_a).to eq([draft, published, archived])
    end

    it "sorts Versionsnummer numerically, not lexicographically" do
      draft.update_columns(version: "1.10")
      published.update_columns(version: "1.2")
      archived.update_columns(version: "1.9")

      result = resolve("sort_by" => "version", "sort_direction" => "asc")

      expect(result.map(&:version)).to eq(["1.2", "1.9", "1.10"])
    end

    it "sorts by a permitted field" do
      expect(resolve("sort_by" => "status", "sort_direction" => "asc").first.status).to eq("archived")
    end
  end

  describe "the shared filters" do
    it "still applies the public filter vocabulary" do
      expect(resolve("districts" => [draft.districts.first.id])).to match_array([draft])
    end
  end
end
