require "rails_helper"

describe MunicipalPlan::ProjektConversion do
  let(:author) { create(:administrator).user }
  let(:lobeda) { create(:registered_address_district, name: "Lobeda") }
  let(:winzerla) { create(:registered_address_district, name: "Winzerla") }
  let(:pin) do
    {
      "type" => "FeatureCollection",
      "features" => [{ "type" => "Feature", "properties" => {},
                       "geometry" => { "type" => "Point", "coordinates" => [11.59, 50.93] }}]
    }
  end
  let(:plan) do
    description = "<p>Ein neues Zentrum.</p><p>Mit Bibliothek.</p>"
    plan = build(:municipal_plan, :published, title: "Stadtteilzentrum Lobeda",
                                              short_description: description)
    plan.district_assignments.clear
    plan.district_assignments.build(district: lobeda)
    plan.district_assignments.build(district: winzerla)
    plan.map_location.assign_attributes(latitude: 50.93, longitude: 11.59, zoom: 15, features: pin,
                                        approximated_address: "Karl-Marx-Allee 1, Jena")
    plan.save!
    plan
  end

  def convert(attributes = {})
    conversion = MunicipalPlan::ProjektConversion.prefilled_for(plan)
    conversion.assign_attributes(attributes)
    conversion.tap { |record| record.save(author: author) }
  end

  describe ".prefilled_for" do
    it "takes the Titel and a plain-text Kurze Beschreibung from the Vorhaben" do
      conversion = MunicipalPlan::ProjektConversion.prefilled_for(plan)

      expect(conversion.name).to eq "Stadtteilzentrum Lobeda"
      expect(conversion.subtitle).to eq "Ein neues Zentrum.\nMit Bibliothek."
    end

    it "decodes the entities the editor stores, so the form shows plain characters" do
      description = "<p>Umwelt &amp; Klima &bdquo;Neue Mitte&ldquo; &lt;Arbeitstitel&gt;</p>"
      plan.update!(short_description: description)

      conversion = MunicipalPlan::ProjektConversion.prefilled_for(plan)

      expect(conversion.subtitle).to eq "Umwelt & Klima „Neue Mitte“ <Arbeitstitel>"
    end

    it "saves an ampersand into the project subtitle without double-escaping it" do
      plan.update!(short_description: "<p>Umwelt &amp; Klima</p>")

      subtitle = convert.projekt.page.subtitle

      expect(subtitle).not_to include("&amp;amp;")
      expect(CGI.unescapeHTML(subtitle)).to eq "Umwelt & Klima"
    end
  end

  describe "#save" do
    it "creates a Beteiligungsprojekt linked to the Vorhaben" do
      projekt = convert.projekt

      expect(projekt).to be_persisted
      expect(projekt.municipal_plan).to eq plan
      expect(projekt.author).to eq author
      expect(projekt.page.title).to eq "Stadtteilzentrum Lobeda"
      expect(projekt.page.subtitle).to eq "Ein neues Zentrum.<br>Mit Bibliothek."
    end

    it "uses the values edited in the form rather than the prefilled ones" do
      projekt = convert(name: "Neues Zentrum Lobeda", subtitle: "Kurz gesagt").projekt

      expect(projekt.page.title).to eq "Neues Zentrum Lobeda"
      expect(projekt.page.subtitle).to eq "Kurz gesagt"
    end

    it "copies the Ortsteile as the project's district affiliation" do
      projekt = convert.projekt.reload

      expect(projekt.geozone_affiliated).to eq "only_geozones"
      expect(projekt.registered_address_district_affiliations).to contain_exactly(lobeda, winzerla)
    end

    it "copies the Kartenposition" do
      map_location = convert.projekt.reload.map_location

      expect(map_location.latitude).to eq 50.93
      expect(map_location.longitude).to eq 11.59
      expect(map_location.zoom).to eq 15
      expect(map_location.features).to eq pin
      expect(map_location.approximated_address).to eq "Karl-Marx-Allee 1, Jena"
    end

    it "leaves the Vorhaben unchanged" do
      plan
      before = plan.reload.attributes.except("updated_at")

      convert

      expect(plan.reload.attributes.except("updated_at")).to eq before
      expect(plan.status).to eq "published"
    end

    it "allows a Vorhaben to be converted more than once" do
      convert
      convert(name: "Zweite Beteiligung")

      expect(plan.projekts.count).to eq 2
    end

    it "refuses a blank title without creating anything" do
      plan

      conversion = nil
      expect { conversion = convert(name: " ") }.not_to change(Projekt, :count)
      expect(conversion.errors.full_messages)
        .to eq [I18n.t("adm.municipal_plans.projekt_conversions.errors.name_blank")]
    end

    it "refuses a subtitle longer than a project allows" do
      plan

      conversion = nil
      expect { conversion = convert(subtitle: "a" * 201) }.not_to change(Projekt, :count)
      expect(conversion.errors.full_messages)
        .to eq [I18n.t("adm.municipal_plans.projekt_conversions.errors.subtitle_too_long", count: 200)]
    end
  end

  describe "the link after the project is gone" do
    it "drops a deleted project from the Vorhaben's visible projects and keeps the Vorhaben" do
      projekt = convert.projekt
      projekt.update!(activated: true)

      projekt.destroy!

      expect(plan.reload).to be_present
      expect(plan.visible_projekts_for(nil)).to be_empty
    end

    it "hides a deactivated project from the public" do
      projekt = convert.projekt
      projekt.update!(activated: false)

      expect(plan.visible_projekts_for(nil)).to be_empty
    end

    it "shows an activated project to the public" do
      projekt = convert.projekt
      projekt.update!(activated: true)

      expect(plan.visible_projekts_for(nil)).to eq [projekt]
    end

    it "unlinks the project when the Vorhaben is deleted" do
      projekt = convert.projekt

      plan.destroy!

      expect(projekt.reload.municipal_plan_id).to be_nil
    end
  end

  describe "Projekt#public_municipal_plan" do
    before do
      allow(Setting).to receive(:[]).and_call_original
      allow(Setting).to receive(:[]).with("process.municipal_plans").and_return(true)
    end

    it "returns a published Vorhaben" do
      expect(convert.projekt.public_municipal_plan).to eq plan
    end

    it "returns nothing once the Vorhaben is back in Entwurf" do
      projekt = convert.projekt
      plan.update_column(:status, "draft")

      expect(projekt.public_municipal_plan).to be_nil
    end

    it "returns nothing while the Vorhabenliste module is off" do
      projekt = convert.projekt
      allow(Setting).to receive(:[]).with("process.municipal_plans").and_return(nil)

      expect(projekt.public_municipal_plan).to be_nil
    end
  end
end
