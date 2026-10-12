require "rails_helper"

describe MunicipalPlans::LegacyImport do
  let(:file) { Rails.root.join("spec/fixtures/files/municipal_plans_legacy_export.csv").to_s }
  let(:officer_group) { create(:municipal_plan_officer_group) }
  let(:report_dir) { Rails.root.join("tmp/spec_legacy_import_#{SecureRandom.hex(4)}") }

  before do
    ["Bauen/Wohnen", "Umwelt / Energie", "Mobilität/Verkehr"].each do |name|
      create(:municipal_plan_topic, name: name)
    end

    ["Jena-Zentrum", "Münchenroda/Remderoda", "Gesamtes Stadtgebiet"].each do |name|
      create(:registered_address_district, name: name)
    end
  end

  after { FileUtils.rm_rf(report_dir) }

  def import(**options)
    MunicipalPlans::LegacyImport.call(file: file, officer_group: officer_group, report_dir: report_dir,
                                      base_url: "https://jena.example", **options)
  end

  def plan(legacy_id)
    MunicipalPlan.find_by!(legacy_id: legacy_id)
  end

  def report(name)
    CSV.read(report_dir.join(name), headers: true)
  end

  def problems_for(legacy_id)
    report("problems.csv").select { |row| row["legacy_id"] == legacy_id }.map { |row| row["problem"] }
  end

  describe "counts" do
    it "imports every titled row under the status its dates call for" do
      result = import

      expect(result.rows_read).to eq(8)
      expect(result.statuses).to eq("published" => 4, "archived" => 1, "draft" => 2)
      expect(result.skipped).to eq(1)
      expect(MunicipalPlan.where.not(legacy_id: nil).count).to eq(7)
    end

    it "skips the fragment without a title and names it in the report" do
      import

      expect(MunicipalPlan.find_by(legacy_id: "5005")).to be_nil
      expect(problems_for("5005")).to eq(["no title, row skipped"])
    end
  end

  describe "splitting the Absätze" do
    it "moves each section into its field and leaves no heading text behind" do
      import
      imported = plan("5001")

      expect(imported.further_information).to eq("Das Plangebiet liegt am Stadtrand.\n\n– Gewerbe ansiedeln")
      expect(imported.last_resolution).to eq("Beschluss des Stadtrates Nr. 19/0057-BV vom 22.01.2020")
      expect(imported.processing_status).to eq("Der Vorentwurf wurde erarbeitet.")
      expect(imported.next_steps).to eq("Der Entwurf folgt im Jahr 2027.")
      expect(imported.costs).to eq("ca. 1,2 Mio. €")

      fields = [imported.further_information, imported.last_resolution, imported.processing_status,
                imported.next_steps]
      fields.each do |value|
        expect(value).not_to match(/<h\d|Bearbeitungsstand|Letzter Beschluss|Betroffenes Gebiet/)
      end
    end

    it "takes the reasons for Bürgerbeteiligung from the section and the flags from the columns" do
      import
      imported = plan("5001")

      expect(imported.formal_participation).to be true
      expect(imported.informal_participation).to be false
      expect(imported.formal_participation_reason)
        .to eq("Die Beteiligung erfolgt im Zuge des Planverfahrens gemäß BauGB.")
      expect(imported.informal_participation_reason).to eq("Derzeit sind keine Gründe erkennbar.")
      expect(plan("5002").informal_participation_reason)
        .to eq("Es gab eine Online-Beteiligung (https://mitmachen.example/x).\n\nZusätzlich eine Begehung.")
    end

    it "clears a cost section that holds only a dash" do
      import

      expect(plan("5002").costs).to be_nil
    end

    it "names a record with unknown sub-headings instead of splitting it" do
      import
      imported = plan("5003")

      expect(imported).to be_draft
      expect(imported.further_information).to include("Letzter politischer Beschluss zum Vorhaben",
                                                      "Einleitung", "Geplanter Zeitpunkt der Umsetzung")
      expect([imported.last_resolution, imported.processing_status, imported.next_steps]).to all(be_nil)
      expect(problems_for("5003")).to include(
        "unknown sub-heading <h3>Letzter politischer Beschluss zum Vorhaben: not split, imported as draft",
        "unknown sub-heading <h4>Geplanter Zeitpunkt der Umsetzung / nächste Schritte: " \
        "not split, imported as draft"
      )
    end

    it "moves a Bürgerbeteiligung without Formell and Informell into the further information" do
      result = import
      imported = plan("5008")

      expect(imported).to be_published
      expect(imported.processing_status).to eq("Fertig")
      expect(imported.further_information)
        .to eq("Bürgerbeteiligung:\nJa\nEs wurden Informationsveranstaltungen durchgeführt.")
      expect(imported.formal_participation_reason).to be_nil
      expect(imported.informal_participation_reason).to be_nil
      expect(imported.informal_participation).to be true
      expect(result.problems.select { |problem| problem.legacy_id == "5008" }.map(&:kind))
        .to eq([:unparsed_participation])
    end

    it "leaves no markup in any imported text" do
      import

      MunicipalPlan.where.not(legacy_id: nil).find_each do |imported|
        MunicipalPlan.translated_attribute_names.each do |field|
          expect(imported.public_send(field).to_s).not_to match(/<[a-z\/]/i)
        end
      end
    end
  end

  describe "umlauts" do
    it "decodes every entity in the title and the text" do
      import
      imported = plan("5002")

      expect(imported.title).to eq("Straßenerneuerung Grüne Aue")
      expect(imported.short_description).to eq("Erneuerung der Straße „Grüne Aue“.")
      expect(imported.further_information)
        .to eq("Die Straße wird für den Verkehr geöffnet & bleibt barrierefrei.")
      expect(imported.last_resolution).to eq("Beschluss vom 01.02.2021 zur Änderung")
      expect(imported.processing_status).to eq("Die Bauarbeiten sind abgeschlossen, die Stadt sagt 'danke'.")
      expect(imported.next_steps).to eq("Keine weiteren Schritte.")
    end

    it "keeps apostrophes of the export" do
      import

      expect(plan("5001").title).to eq("Bebauungsplan B-Lo 13 \"Möbelhaus 'An der Autobahn'\"")
    end
  end

  describe "status and dates" do
    it "archives a Vorhaben whose Archivdatum lies in the past" do
      import
      archived = plan("5002")

      expect(archived).to be_archived
      expect(archived.archive_on).to eq(Date.new(2023, 3, 1))
      expect(archived.released_at.to_date).to eq(Date.new(2023, 1, 15))
    end

    it "publishes an open-ended Vorhaben without an Archivdatum" do
      import

      expect(plan("5001")).to be_published
      expect(plan("5001").archive_on).to be_nil
    end

    it "keeps the Versionsnummer and the dates of the export" do
      import
      imported = plan("5001")

      expect(imported.version).to eq("2.1")
      expect(imported.content_updated_at).to eq(Date.new(2024, 5, 10))
      expect(imported.created_at.to_date).to eq(Date.new(2024, 5, 10))
      expect(imported.released_at.to_date).to eq(Date.new(2024, 5, 10))
      expect(plan("5007").version).to eq("0.1")
    end

    it "shows neither \"neu\" nor \"aktualisiert\" right after the import" do
      import

      MunicipalPlan.where.not(legacy_id: nil).find_each do |imported|
        expect(imported.newly_added?).to be false
        expect(imported.recently_updated?).to be false
        expect(imported.badges).not_to include(:new, :updated)
      end
    end

    it "sends no mail and leaves neither audits nor activity behind" do
      expect { import }.not_to change { ActionMailer::Base.deliveries.count }

      ids = MunicipalPlan.where.not(legacy_id: nil).ids
      expect(Audited::Audit.where(auditable_type: "MunicipalPlan", auditable_id: ids)).to be_empty
      expect(SectionActivity.where(trackable_type: "MunicipalPlan", trackable_id: ids)).to be_empty
    end
  end

  describe "release validation" do
    it "publishes a Vorhaben without a Kartenposition" do
      import
      imported = plan("5001")

      expect(imported.map_location).to be_nil
      expect(imported).to be_published
      expect(imported).to be_valid
    end

    it "falls back to Entwurf when other required fields are missing and says why" do
      result = import

      expect(plan("5007")).to be_draft
      expect(result.problems.select { |problem| problem.legacy_id == "5007" }.map(&:kind))
        .to include(:draft_fallback)
    end
  end

  describe "assignments" do
    it "gives every Vorhaben the officer group and the placeholder contact" do
      import

      expect(plan("5001").responsible).to eq(officer_group)
      expect(plan("5001").contact_name).to eq("Zentrale Stelle – bitte ersetzen")
    end

    it "takes the contact from the options" do
      import(contact: { name: "Bürgerbüro", email: "buergerbuero@jena.example" })

      expect(plan("5001").contact_name).to eq("Bürgerbüro")
      expect(plan("5001").contact_email).to eq("buergerbuero@jena.example")
    end

    it "matches Themen and Ortsteile regardless of the spacing around the slash" do
      import

      expect(plan("5001").topics.map(&:name)).to match_array(["Bauen/Wohnen", "Umwelt / Energie"])
      expect(plan("5001").districts.map(&:name)).to match_array(["Jena-Zentrum", "Münchenroda/Remderoda"])
    end

    it "reports an Ortsteil it cannot find and keeps the others" do
      import

      expect(plan("5004").districts.map(&:name)).to eq(["Jena-Zentrum"])
      expect(problems_for("5004")).to include("Ortsteil not found: Atlantis")
    end

    it "reports an Ortsteil whose name several districts share" do
      create(:registered_address_district, name: "Gesamtes Stadtgebiet")

      import

      expect(problems_for("5002")).to include("Ortsteil ambiguous (2 matches): Gesamtes Stadtgebiet")
      expect(plan("5002")).to be_draft
    end

    it "creates one titled link per URL in the order of the export" do
      import

      expect(plan("5001").links.map { |link| [link.title, link.url] }).to eq([
        ["Beschlussvorlage 17476 (Ratsinformationssystem)",
         "https://sessionnet.owl-it.de/jena/bi/vo0050.asp?__kvonr=17476&smcspf=4"],
        ["Dokument Satzung_Grüne-Aue (PDF)",
         "https://rathaus.jena.de/system/files/2026-06/Satzung_Gr%C3%BCne-Aue.pdf"],
        ["www.jena.de", "https://www.jena.de/stadtentwicklung"]
      ])
    end
  end

  describe "the reports" do
    it "lists every Beteiligung contradiction" do
      import

      expect(report("participation_conflicts.csv").map(&:to_h)).to eq([
        { "legacy_id" => "5004", "title" => "Radweg Saale", "flag" => "off", "formell" => "on",
          "informell" => "off" }
      ])
      expect(problems_for("5004")).to include(
        "Bürgerbeteiligung formell: text says Nein, column says on (column kept)",
        "status \"in Arbeit\" ignored"
      )
    end

    it "names possible duplicates" do
      import

      expect(problems_for("5001")).to include("possible duplicate, same title as 5006")
      expect(problems_for("5006")).to include("possible duplicate, same title as 5001")
    end

    it "maps every imported Vorhaben to its new address" do
      import

      mapping = report("mapping.csv")
      expect(mapping.map { |row| row["legacy_id"] }).to match_array(%w[5001 5002 5003 5004 5006 5007 5008])
      expect(mapping.find { |row| row["legacy_id"] == "5001" }["new_url"])
        .to eq("https://jena.example/municipal_plans/#{plan("5001").id}")
    end
  end

  describe "running twice" do
    it "overwrites instead of duplicating" do
      import
      first = plan("5001")
      first.translations.update_all(processing_status: "Von Hand geändert")

      counts = lambda do
        [MunicipalPlan.count, MunicipalPlan::Link.count, MunicipalPlan::TopicAssignment.count,
         MunicipalPlan::DistrictAssignment.count]
      end

      expect { import }.not_to change(&counts)

      expect(plan("5001").id).to eq(first.id)
      expect(plan("5001").processing_status).to eq("Der Vorentwurf wurde erarbeitet.")
      expect(plan("5001").version).to eq("2.1")
    end

    it "keeps the Versionsnummer of a row that has none in the export" do
      import
      version = plan("5007").version
      plan("5007").translations.update_all(processing_status: "Von Hand geändert")

      import

      expect(plan("5007").version).to eq(version)
    end

    it "leaves a Vorhaben untouched when it cannot be saved again" do
      import
      original = plan("5001")
      assignments = lambda do
        [original.links.count, original.topic_assignments.count, original.district_assignments.count]
      end
      before_rerun = assignments.call

      allow_any_instance_of(MunicipalPlan).to receive(:save).and_wrap_original do |method, *args|
        method.receiver.legacy_id == "5001" ? false : method.call(*args)
      end

      import

      expect(assignments.call).to eq(before_rerun)
      expect(problems_for("5001")).to include(a_string_starting_with("not imported"))
    end
  end

  describe "dry run" do
    it "writes the reports but nothing else" do
      result = import(dry_run: true)

      expect(MunicipalPlan.where.not(legacy_id: nil)).to be_empty
      expect(MunicipalPlan::Link.count).to eq(0)
      expect(result.statuses["published"]).to eq(4)
      expect(report("mapping.csv").map { |row| row["new_id"] }).to all(be_nil)
      expect(report("problems.csv").count).to be_positive
    end
  end

  describe "missing Themen" do
    it "aborts before writing anything and names them" do
      MunicipalPlan::Topic.find_by!(name: "Umwelt / Energie").destroy!

      expect { import }.to raise_error(MunicipalPlans::LegacyImport::MissingTopicsError, /Umwelt\/Energie/)
      expect(MunicipalPlan.count).to eq(0)
      expect(report_dir).not_to exist
    end
  end
end
