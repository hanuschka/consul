require "rails_helper"

describe "Vorhabenliste", type: :request do
  let(:officer) { create(:municipal_plan_officer) }
  let(:plan) do
    create(:municipal_plan, :published,
           responsible: officer,
           title: "Weiterentwicklung des Eichplatz-Areals",
           system_mailbox_email: "postfach@jena.example").tap do |created|
      created.memos.create!(user: officer.user, text: "Interner Vermerk der Sachbearbeitung")
    end
  end

  before do
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
    allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)
  end

  def enable_module(enabled)
    allow(Setting).to receive(:[]).and_call_original
    allow(Setting).to receive(:[]).with("process.municipal_plans").and_return(enabled)
  end

  describe "the module setting" do
    it "keeps the overview unreachable when it is off" do
      enable_module(nil)

      expect { get municipal_plans_path }.to raise_error(FeatureFlags::FeatureDisabled)
    end

    it "keeps the detail page unreachable when it is off" do
      enable_module(nil)
      plan

      expect { get municipal_plan_path(plan) }.to raise_error(FeatureFlags::FeatureDisabled)
    end

    it "keeps the archive unreachable when it is off" do
      enable_module(nil)

      expect { get archive_municipal_plans_path }.to raise_error(FeatureFlags::FeatureDisabled)
    end

    it "keeps the pages unreachable for a signed-in visitor too when it is off" do
      enable_module(nil)
      login_as(create(:user))

      expect { get municipal_plan_path(plan) }.to raise_error(FeatureFlags::FeatureDisabled)
    end

    it "answers that refusal with 403 in front of a user" do
      expect(Rails.application.config.action_dispatch.rescue_responses["FeatureFlags::FeatureDisabled"])
        .to eq(:forbidden)
    end

    it "renders the overview when it is on" do
      enable_module(true)
      plan

      get municipal_plans_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Weiterentwicklung des Eichplatz-Areals")
    end

    it "renders the detail page when it is on" do
      enable_module(true)

      get municipal_plan_path(plan)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Weiterentwicklung des Eichplatz-Areals")
    end

    it "offers no navigation preset when it is off" do
      enable_module(nil)

      expect(NavbarItem.enabled_presets.keys).not_to include(:municipal_plans)
    end

    it "offers a navigation preset when it is on" do
      enable_module(true)

      expect(NavbarItem.enabled_presets.keys).to include(:municipal_plans)
    end
  end

  describe "which plans are public" do
    before { enable_module(true) }

    it "hides a draft" do
      draft = create(:municipal_plan, responsible: officer)

      expect { get municipal_plan_path(draft) }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "keeps an archived plan off the overview but reachable" do
      archived = create(:municipal_plan, :published, responsible: officer,
                                                     title: "Abgeschlossen und archiviert")
      archived.update!(status: "archived")

      get municipal_plans_path

      expect(response.body).not_to include("Abgeschlossen und archiviert")

      get municipal_plan_path(archived)

      expect(response).to have_http_status(:ok)
    end

    it "lists only published plans on the overview" do
      plan
      create(:municipal_plan, responsible: officer, title: "Noch nicht freigegeben")

      get municipal_plans_path

      expect(response.body).to include("Weiterentwicklung des Eichplatz-Areals")
      expect(response.body).not_to include("Noch nicht freigegeben")
    end
  end

  describe "linked participation projects on the detail page" do
    before { enable_module(true) }

    it "links an activated project and leaves out deactivated and deleted ones" do
      active = create(:projekt, name: "Beteiligung Eichplatz", municipal_plan: plan)
      create(:projekt, :deactivated, name: "Deaktivierte Beteiligung", municipal_plan: plan)
      create(:projekt, name: "Gelöschte Beteiligung", municipal_plan: plan).destroy!

      get municipal_plan_path(plan)

      block = Nokogiri::HTML(response.body).at_css(".municipal-plan-participation")
      rows = block.css(".municipal-plan-participation--projekt")

      expect(rows.size).to eq 1
      expect(rows.first.text)
        .to include(I18n.t("custom.municipal_plans.show.participation_block.projekt_text"))
      expect(rows.first.at_css("a[href='#{page_path(active.page.slug)}']").text)
        .to include(I18n.t("custom.municipal_plans.show.participation_block.projekt_button"))
      expect(response.body).to include("Beteiligung Eichplatz")
      expect(response.body).not_to include("Deaktivierte Beteiligung")
      expect(response.body).not_to include("Gelöschte Beteiligung")
    end

    it "renders one row per linked project, naming each one" do
      first = create(:projekt, name: "Beteiligung Eichplatz", municipal_plan: plan)
      second = create(:projekt, name: "Beteiligung Inselplatz", municipal_plan: plan)

      get municipal_plan_path(plan)

      rows = Nokogiri::HTML(response.body).css(".municipal-plan-participation--projekt")

      expect(rows.size).to eq 2
      expect(rows.map { |row| row.at_css("strong").text.strip })
        .to match_array ["Beteiligung Eichplatz", "Beteiligung Inselplatz"]
      expect(rows.map { |row| row.at_css("a")["href"] })
        .to match_array [page_path(first.page.slug), page_path(second.page.slug)]
    end

    it "shows no related-project row when no project is linked" do
      get municipal_plan_path(plan)

      expect(Nokogiri::HTML(response.body).css(".municipal-plan-participation--projekt")).to be_empty
    end
  end

  describe "search and sorting" do
    # The search dictionary comes from I18n.default_locale, which is :en in the test environment
    # and :de on a German instance. Stemming and weighting are only meaningful under German.
    around do |example|
      original = I18n.default_locale
      I18n.default_locale = :de
      example.run
      I18n.default_locale = original
    end

    before { enable_module(true) }

    let!(:in_title) do
      create(:municipal_plan, :published, responsible: officer,
                                          title: "Sanierung der Brücke am Markt")
    end
    let!(:in_body) do
      create(:municipal_plan, :published, responsible: officer,
                                          title: "Umbau Eichplatz",
                                          short_description: "Neue Brücke geplant")
    end

    def titles_in_order
      response.body.scan(/Sanierung der Brücke am Markt|Umbau Eichplatz/).uniq
    end

    it "ranks a Titel match above a Kurze Beschreibung match" do
      get municipal_plans_path(search: "Brücke")

      expect(titles_in_order.first).to eq("Sanierung der Brücke am Markt")
    end

    it "finds a stem when the search word is inflected" do
      get municipal_plans_path(search: "Brücken")

      expect(response.body).to include("Sanierung der Brücke am Markt")
      expect(response.body).to include("Umbau Eichplatz")
    end

    it "sorts by editorial order when nothing is searched" do
      in_title.update!(given_order: 2)
      in_body.update!(given_order: 1)

      get municipal_plans_path

      expect(titles_in_order.first).to eq("Umbau Eichplatz")
    end

    it "sorts by title when asked" do
      get municipal_plans_path(order: "title")

      expect(titles_in_order.first).to eq("Sanierung der Brücke am Markt")
    end
  end

  describe "administration-only filters stay out of the public area" do
    before do
      enable_module(true)
      create(:municipal_plan, responsible: officer, title: "Nicht freigegeben")
    end

    shared_examples "no administration filters" do
      it "offers neither a Status nor a Zuständigkeit filter" do
        get municipal_plans_path

        expect(response.body).not_to match(/name="status/)
        expect(response.body).not_to match(/name="responsible/)
      end

      it "ignores a hand-crafted status parameter instead of revealing drafts" do
        get municipal_plans_path(status: ["draft"])

        expect(response.body).not_to include("Nicht freigegeben")
      end

      it "ignores a hand-crafted responsible parameter" do
        get municipal_plans_path(responsible: ["Officer:#{officer.id}"])

        expect(response.body).not_to include("Nicht freigegeben")
      end
    end

    context "for an anonymous visitor" do
      include_examples "no administration filters"
    end

    context "for a signed-in administrator" do
      before { login_as(create(:administrator).user) }

      include_examples "no administration filters"
    end
  end

  describe "internal data never reaches the public detail page" do
    before { enable_module(true) }

    shared_examples "hides internal data" do
      it "shows neither the internal notes nor the system mailbox nor the case worker" do
        get municipal_plan_path(plan)

        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("Interner Vermerk der Sachbearbeitung")
        expect(response.body).not_to include("postfach@jena.example")
        expect(response.body).not_to include(officer.name)
      end

      it "shows no change log" do
        plan.update!(processing_status: "Neuer Stand")

        get municipal_plan_path(plan)

        expect(plan.own_and_associated_audits).to be_any
        expect(response.body).not_to include(plan.own_and_associated_audits.last.id.to_s +
                                             "/audits")
        expect(response.body).not_to match(/audits/i)
      end
    end

    context "for an anonymous visitor" do
      include_examples "hides internal data"
    end

    context "for a signed-in citizen" do
      before { login_as(create(:user)) }

      include_examples "hides internal data"
    end

    context "for a signed-in administrator" do
      before { login_as(create(:administrator).user) }

      include_examples "hides internal data"
    end
  end

  describe "a change waiting for release" do
    before { enable_module(true) }

    it "keeps showing the released text, and keeps the Vorhaben in the list" do
      plan.update_columns(content_updated_at: Date.current - 10.days)
      copy = ::MunicipalPlans::WorkingCopyService.call(plan)
      copy.update!(title: "Noch nicht freigegebene Überschrift")

      get municipal_plan_path(plan)

      expect(response.body).to include("Weiterentwicklung des Eichplatz-Areals")
      expect(response.body).not_to include("Noch nicht freigegebene Überschrift")
      expect(plan.reload.content_updated_at).to eq(Date.current - 10.days)

      get municipal_plans_path

      expect(response.body).to include("Weiterentwicklung des Eichplatz-Areals")
      expect(response.body).not_to include("Noch nicht freigegebene Überschrift")
    end

    it "shows the new text once it is released" do
      copy = ::MunicipalPlans::WorkingCopyService.call(plan)
      copy.update!(title: "Freigegebene Überschrift", submitted_at: Time.current)
      ::MunicipalPlans::ReleaseService.call(copy)

      get municipal_plan_path(plan)

      expect(response.body).to include("Freigegebene Überschrift")
    end

    it "never exposes the working copy on its own" do
      copy = ::MunicipalPlans::WorkingCopyService.call(plan)

      expect { get municipal_plan_path(copy) }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "the editorial order on the overview" do
    before { enable_module(true) }

    let!(:back) do
      create(:municipal_plan, :published, responsible: officer, title: "Hinten einsortiert",
                                          given_order: 3)
    end
    let!(:front) do
      create(:municipal_plan, :published, responsible: officer, title: "Vorne einsortiert",
                                          given_order: 1)
    end

    it "follows the order set in the administration" do
      get municipal_plans_path

      expect(response.body.index("Vorne einsortiert")).to be < response.body.index("Hinten einsortiert")

      MunicipalPlan.apply_editorial_order([back.id, front.id])

      get municipal_plans_path

      expect(response.body.index("Hinten einsortiert")).to be < response.body.index("Vorne einsortiert")
    end

    it "comes back after a visitor sorted by Titel" do
      MunicipalPlan.apply_editorial_order([back.id, front.id])

      get municipal_plans_path(order: "title")

      expect(response.body.index("Hinten einsortiert")).to be < response.body.index("Vorne einsortiert")

      get municipal_plans_path

      expect(response.body.index("Hinten einsortiert")).to be < response.body.index("Vorne einsortiert")
      expect([back, front].map { |plan| plan.reload.given_order }).to eq([1, 2])
    end
  end

  describe "the archive" do
    before do
      enable_module(true)
      create(:municipal_plan, :published, responsible: officer, title: "Laufendes Vorhaben")
    end

    let!(:archived) do
      create(:municipal_plan, :published, responsible: officer, title: "Abgeschlossenes Vorhaben")
        .tap { |plan| plan.update!(status: "archived") }
    end

    it "keeps the archived Vorhaben out of the main overview" do
      get municipal_plans_path

      expect(response.body).to include("Laufendes Vorhaben")
      expect(response.body).not_to include("Abgeschlossenes Vorhaben")
    end

    it "shows only archived Vorhaben in the archive" do
      get archive_municipal_plans_path

      expect(response.body).to include("Abgeschlossenes Vorhaben")
      expect(response.body).not_to include("Laufendes Vorhaben")
    end

    it "keeps the detail page reachable at its unchanged address" do
      get municipal_plan_path(archived)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Abgeschlossenes Vorhaben")
    end

    it "filters the archive the same way as the main list" do
      district = create(:registered_address_district)
      archived.district_assignments.destroy_all
      archived.district_assignments.create!(district: district)
      other = create(:municipal_plan, :published, responsible: officer, title: "Anderer Ortsteil")
      other.update!(status: "archived")

      get archive_municipal_plans_path(districts: [district.id])

      expect(response.body).to include("Abgeschlossenes Vorhaben")
      expect(response.body).not_to include("Anderer Ortsteil")
    end

    it "keeps the filter form inside the archive" do
      get archive_municipal_plans_path

      expect(response.body).to include(%(action="#{archive_municipal_plans_path}"))
    end

    it "searches the archive" do
      get archive_municipal_plans_path(search: "Abgeschlossenes")

      expect(response.body).to include("Abgeschlossenes Vorhaben")
    end

    it "still hides an Entwurf" do
      draft = create(:municipal_plan, responsible: officer, title: "Nicht freigegeben")

      get archive_municipal_plans_path

      expect(response.body).not_to include("Nicht freigegeben")
      expect { get municipal_plan_path(draft) }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "the Ortsteil map" do
    before { enable_module(true) }

    let(:area) do
      {
        "type" => "FeatureCollection",
        "features" => [{
          "type" => "Feature",
          "properties" => {},
          "geometry" => {
            "type" => "Polygon",
            "coordinates" => [[[11.58, 50.92], [11.60, 50.92], [11.60, 50.94], [11.58, 50.92]]]
          }
        }]
      }
    end

    def map_wrapper
      Nokogiri::HTML(response.body).at_css(".js-municipal-plans-map")
    end

    def area_properties
      container = map_wrapper.at_css(".js-municipal-plans-map-container")
      JSON.parse(container["data-areas"])["features"].map { |feature| feature["properties"] }
    end

    it "is not rendered on an instance where no Ortsteil areas were loaded" do
      create(:registered_address_district, name: "Lobeda")
      plan

      get municipal_plans_path

      expect(response).to have_http_status(:ok)
      expect(map_wrapper).to be_nil
      expect(response.body).to include("Weiterentwicklung des Eichplatz-Areals")
    end

    it "carries the Ortsteil areas and marks the selected one" do
      lobeda = create(:registered_address_district, name: "Lobeda")
      create(:map_location, mappable: lobeda, features: area)
      wenigenjena = create(:registered_address_district, name: "Wenigenjena")
      create(:map_location, mappable: wenigenjena, features: area)

      get municipal_plans_path(districts: [lobeda.id])

      expect(area_properties).to contain_exactly(
        { "district_id" => lobeda.id, "name" => "Lobeda", "selected" => true },
        { "district_id" => wenigenjena.id, "name" => "Wenigenjena", "selected" => false }
      )
    end

    it "is rendered in the archive too" do
      lobeda = create(:registered_address_district, name: "Lobeda")
      create(:map_location, mappable: lobeda, features: area)

      get archive_municipal_plans_path

      expect(map_wrapper).to be_present
    end
  end

  describe "the list" do
    before { enable_module(true) }

    def document
      Nokogiri::HTML(response.body)
    end

    def item_titles
      document.css(".resources-list--inner .resource-item--title").map { |title| title.text.strip }
    end

    it "offers the shared view-mode button in the list toolbar" do
      plan

      get municipal_plans_path

      expect(document.at_css(".resources-list .js-resource-list-switch-view-button")).to be_present
    end

    it "shows the result count in the sidebar information card as a status" do
      plan

      get municipal_plans_path

      count = document.at_css("#municipal-plans-sidebar .resources--info-count[role=status]")
      expect(count.css("span").map { |node| node.text.strip })
        .to eq [I18n.t("custom.municipal_plans.index.count"), "1"]
      expect(document.css("[role=status]").size).to eq 1
    end

    it "shows every Ortsteil of a Vorhaben" do
      names = %w[Lobeda Wenigenjena Winzerla Zwätzen]
      plan.district_assignments.destroy_all
      names.each do |name|
        plan.district_assignments.create!(district: create(:registered_address_district, name: name))
      end

      get municipal_plans_path

      item_text = document.at_css(".resources-list--inner .resource-item").text
      names.each { |name| expect(item_text).to include(name) }
    end

    it "applies the Ortsteil filter and keeps it checked" do
      district = create(:registered_address_district, name: "Lobeda")
      plan.district_assignments.destroy_all
      plan.district_assignments.create!(district: district)
      create(:municipal_plan, :published, responsible: officer, title: "Anderer Ortsteil")

      get municipal_plans_path(districts: [district.id])

      expect(item_titles).to eq ["Weiterentwicklung des Eichplatz-Areals"]
      expect(document.at_css("#filter_district_#{district.id}")["checked"]).to be_present
    end

    it "lists the newest update first when sorted by Aktualisierungsdatum" do
      older = create(:municipal_plan, :published, responsible: officer, title: "Älteres Vorhaben")
      newer = create(:municipal_plan, :published, responsible: officer, title: "Neueres Vorhaben")
      older.update_columns(content_updated_at: Date.current - 20.days)
      newer.update_columns(content_updated_at: Date.current - 2.days)

      get municipal_plans_path(order: "content_updated_at")

      expect(item_titles).to eq ["Neueres Vorhaben", "Älteres Vorhaben"]
    end
  end

  describe "the table view" do
    before do
      enable_module(true)
      cookies["wide_resources"] = "true"
    end

    def document
      Nokogiri::HTML(response.body)
    end

    def row_for(title)
      document.css("table tbody tr").find { |row| row.at_css("th[scope=row]")&.text&.strip == title }
    end

    def row_titles
      document.css("table tbody tr th[scope=row]").map { |cell| cell.text.strip }
    end

    it "renders a table with five column headers and the linked title" do
      plan

      get municipal_plans_path

      html = document
      html.css(".municipal-plans-table--sort-hint").each(&:remove)
      headers = html.css(".municipal-plans-table table thead th[scope=col]").map { |th| th.text.strip }
      expect(headers).to eq %w[title date topics districts badges].map { |key|
        I18n.t("custom.municipal_plans.index.table.columns.#{key}")
      }
      link = row_for("Weiterentwicklung des Eichplatz-Areals").at_css("a")
      expect(link["href"]).to eq municipal_plan_path(plan)
    end

    it "keeps the table semantics as explicit ARIA roles" do
      plan

      get municipal_plans_path

      region = document.at_css(".municipal-plans-table > .municipal-plans-table--scroll[role=region]")
      expect(region["aria-label"]).to eq I18n.t("custom.municipal_plans.index.table.region_label")
      table = region.at_css("table[role=table]")
      caption = table.at_css("caption")
      expect(caption["id"]).to be_present
      expect(table["aria-labelledby"]).to eq caption["id"]
      expect(caption.text.strip).to eq I18n.t("custom.municipal_plans.index.table.caption")
      expect(table.css("thead[role=rowgroup] tr[role=row] [role=columnheader]").size).to eq 5
      rows = table.css("tbody[role=rowgroup] > tr")
      expect(rows).not_to be_empty
      rows.each do |row|
        expect(row["role"]).to eq "row"
        expect(row.css("[role=rowheader]").size).to eq 1
        expect(row.css("> [role=cell]").size).to eq 4
      end
    end

    it "shows every Ortsteil of a Vorhaben" do
      names = %w[Lobeda Wenigenjena Winzerla Zwätzen]
      plan.district_assignments.destroy_all
      names.each do |name|
        plan.district_assignments.create!(district: create(:registered_address_district, name: name))
      end

      get municipal_plans_path

      label = I18n.t("custom.municipal_plans.index.table.columns.districts")
      districts_cell = row_for("Weiterentwicklung des Eichplatz-Areals").at_css("td[data-label='#{label}']")
      names.each { |name| expect(districts_cell.text).to include(name) }
    end

    it "applies the Ortsteil filter and keeps it checked" do
      district = create(:registered_address_district, name: "Lobeda")
      plan.district_assignments.destroy_all
      plan.district_assignments.create!(district: district)
      create(:municipal_plan, :published, responsible: officer, title: "Anderer Ortsteil")

      get municipal_plans_path(districts: [district.id])

      expect(row_titles).to eq ["Weiterentwicklung des Eichplatz-Areals"]
      expect(document.at_css("#filter_district_#{district.id}")["checked"]).to be_present
    end

    it "lists the newest update first when sorted by Aktualisierungsdatum" do
      older = create(:municipal_plan, :published, responsible: officer, title: "Älteres Vorhaben")
      newer = create(:municipal_plan, :published, responsible: officer, title: "Neueres Vorhaben")
      older.update_columns(content_updated_at: Date.current - 20.days)
      newer.update_columns(content_updated_at: Date.current - 2.days)

      get municipal_plans_path(order: "content_updated_at")

      expect(row_titles).to eq ["Neueres Vorhaben", "Älteres Vorhaben"]
      label = I18n.t("custom.municipal_plans.index.table.columns.date")
      expect(row_for("Neueres Vorhaben").at_css("td[data-label='#{label}']").text.strip)
        .to eq (Date.current - 2.days).strftime("%d.%m.%Y")
    end

    it "lists the oldest update first when sorted by Aktualisierungsdatum ascending" do
      older = create(:municipal_plan, :published, responsible: officer, title: "Älteres Vorhaben")
      newer = create(:municipal_plan, :published, responsible: officer, title: "Neueres Vorhaben")
      older.update_columns(content_updated_at: Date.current - 20.days)
      newer.update_columns(content_updated_at: Date.current - 2.days)

      get municipal_plans_path(order: "content_updated_at_asc")

      expect(row_titles).to eq ["Älteres Vorhaben", "Neueres Vorhaben"]
    end

    it "lists the titles from Z to A when sorted by title descending" do
      create(:municipal_plan, :published, responsible: officer, title: "Ausbau Radweg")
      create(:municipal_plan, :published, responsible: officer, title: "Zentrale Bushaltestelle")

      get municipal_plans_path(order: "title_desc")

      expect(row_titles).to eq ["Zentrale Bushaltestelle", "Ausbau Radweg"]
    end

    it "lists a Vorhaben without Aktualisierungsdatum last in both directions" do
      undated = create(:municipal_plan, :published, responsible: officer, title: "Ohne Datum")
      dated = create(:municipal_plan, :published, responsible: officer, title: "Mit Datum")
      undated.update_columns(content_updated_at: nil)
      dated.update_columns(content_updated_at: Date.current - 2.days)

      get municipal_plans_path(order: "content_updated_at")
      expect(row_titles).to eq ["Mit Datum", "Ohne Datum"]

      get municipal_plans_path(order: "content_updated_at_asc")
      expect(row_titles).to eq ["Mit Datum", "Ohne Datum"]
    end

    def header_link(key)
      document.at_css(".municipal-plans-table thead th.municipal-plans-table--#{key} a")
    end

    def link_query(link)
      Rack::Utils.parse_nested_query(URI.parse(link["href"]).query)
    end

    it "links the Vorhaben header to the A-Z order by default" do
      plan

      get municipal_plans_path

      link = header_link(:title)
      expect(URI.parse(link["href"]).path).to eq municipal_plans_path
      expect(link_query(link)).to eq("order" => "title")
      expect(link.at_css(".municipal-plans-table--sort-hint").text.strip)
        .to eq I18n.t("custom.municipal_plans.index.table.sort.ascending")
      expect(link_query(header_link(:date))).to eq("order" => "content_updated_at")
    end

    it "links the Vorhaben header to the Z-A order when sorted by title, keeping filters" do
      district = create(:registered_address_district, name: "Lobeda")
      topic = create(:municipal_plan_topic)
      plan.district_assignments.destroy_all
      plan.district_assignments.create!(district: district)
      plan.topic_assignments.create!(topic: topic)

      get municipal_plans_path(order: "title", districts: [district.id], topics: [topic.id],
                               search: "Eichplatz", page: 2)

      query = link_query(header_link(:title))
      expect(query).to eq("order" => "title_desc", "districts" => [district.id.to_s],
                          "topics" => [topic.id.to_s], "search" => "Eichplatz")
    end

    it "links the Datum header to the oldest-first order when sorted newest first" do
      plan

      get municipal_plans_path(order: "content_updated_at")

      expect(link_query(header_link(:date))).to eq("order" => "content_updated_at_asc")
    end

    it "marks only the sorted column with aria-sort" do
      plan

      get municipal_plans_path(order: "title_desc")

      headers = document.css(".municipal-plans-table thead th")
      expect(headers.map { |th| th["aria-sort"] }).to eq ["descending", nil, nil, nil, nil]
      expect(headers.first.at_css(".fa-sort-down[aria-hidden=true]")).to be_present
      expect(headers[1].at_css(".fa-sort[aria-hidden=true]")).to be_present
      expect(headers[2].at_css(".fa-sort[aria-hidden=true]")).to be_present
      expect(headers[4].at_css("a")).to be_nil

      get municipal_plans_path(order: "content_updated_at_asc")

      expect(document.css(".municipal-plans-table thead th").map { |th| th["aria-sort"] })
        .to eq [nil, "ascending", nil, nil, nil]
    end

    def plan_with_topics(title, names)
      create(:municipal_plan, :published, responsible: officer, title: title).tap do |created|
        created.topic_assignments.destroy_all
        names.each do |name|
          created.topic_assignments.create!(topic: create(:municipal_plan_topic, name: name))
        end
      end
    end

    def plan_with_districts(title, names)
      create(:municipal_plan, :published, responsible: officer, title: title).tap do |created|
        created.district_assignments.destroy_all
        names.each do |name|
          created.district_assignments.create!(district: create(:registered_address_district, name: name))
        end
      end
    end

    def cell_text(title, key)
      label = I18n.t("custom.municipal_plans.index.table.columns.#{key}")
      row_for(title).at_css("td[data-label='#{label}']").text.strip
    end

    it "sorts by the first Kategorie, listing a Vorhaben without Kategorie last in both directions" do
      plan_with_topics("Ohne Kategorie", [])
      plan_with_topics("Umwelt und Mobilität", %w[Umwelt Mobilität])
      plan_with_topics("Ärztehaus", %w[Zuwanderung Ärzte])
      plan_with_topics("Bauen", %w[bauen])

      get municipal_plans_path(order: "topics")
      expect(row_titles).to eq ["Ärztehaus", "Bauen", "Umwelt und Mobilität", "Ohne Kategorie"]

      get municipal_plans_path(order: "topics_desc")
      expect(row_titles).to eq ["Umwelt und Mobilität", "Bauen", "Ärztehaus", "Ohne Kategorie"]
    end

    it "sorts by the first Ort, listing a Vorhaben without Ort last in both directions" do
      plan_with_districts("Ohne Ort", [])
      plan_with_districts("Zwätzen und Lobeda", %w[Zwätzen Lobeda])
      plan_with_districts("Ammerbach", %w[Winzerla Ammerbach])
      plan_with_districts("Drackendorf", %w[drackendorf])

      get municipal_plans_path(order: "districts")
      expect(row_titles).to eq ["Ammerbach", "Drackendorf", "Zwätzen und Lobeda", "Ohne Ort"]

      get municipal_plans_path(order: "districts_desc")
      expect(row_titles).to eq ["Zwätzen und Lobeda", "Drackendorf", "Ammerbach", "Ohne Ort"]
    end

    it "lists the Kategorien and Orte of a Vorhaben alphabetically" do
      plan_with_topics("Sortierte Namen", %w[Mobilität Bauen]).tap do |created|
        created.district_assignments.destroy_all
        %w[Zwätzen Lobeda].each do |name|
          created.district_assignments.create!(district: create(:registered_address_district, name: name))
        end
      end

      get municipal_plans_path

      expect(cell_text("Sortierte Namen", :topics)).to eq "Bauen, Mobilität"
      expect(cell_text("Sortierte Namen", :districts)).to eq "Lobeda, Zwätzen"
    end

    it "links the Kategorie and Ort headers to the A-Z order by default" do
      plan

      get municipal_plans_path

      expect(link_query(header_link(:topics))).to eq("order" => "topics")
      expect(link_query(header_link(:districts))).to eq("order" => "districts")
      expect(header_link(:topics).at_css(".municipal-plans-table--sort-hint").text.strip)
        .to eq I18n.t("custom.municipal_plans.index.table.sort.ascending")
    end

    it "links the Kategorie and Ort headers to the Z-A order when sorted by them, keeping filters" do
      district = create(:registered_address_district, name: "Lobeda")
      topic = create(:municipal_plan_topic)
      plan.district_assignments.destroy_all
      plan.district_assignments.create!(district: district)
      plan.topic_assignments.create!(topic: topic)
      filters = { "districts" => [district.id.to_s], "topics" => [topic.id.to_s], "search" => "Eichplatz" }

      get municipal_plans_path(order: "topics", districts: [district.id], topics: [topic.id],
                               search: "Eichplatz", page: 2)

      expect(link_query(header_link(:topics))).to eq filters.merge("order" => "topics_desc")
      expect(link_query(header_link(:districts))).to eq filters.merge("order" => "districts")
      expect(document.css(".municipal-plans-table thead th").map { |th| th["aria-sort"] })
        .to eq [nil, nil, "ascending", nil, nil]

      get municipal_plans_path(order: "districts", districts: [district.id], topics: [topic.id],
                               search: "Eichplatz")

      expect(link_query(header_link(:districts))).to eq filters.merge("order" => "districts_desc")
      expect(document.css(".municipal-plans-table thead th").map { |th| th["aria-sort"] })
        .to eq [nil, nil, nil, "ascending", nil]
    end

    it "lists the Kategorie and Ort orders in the sort dropdown" do
      plan

      get municipal_plans_path(order: "topics")

      dropdown = document.at_css(".resources-list--filter dropdown-select-menu")
      orders = dropdown.css("a").map { |link| link_query(link)["order"] }
      expect(orders).to eq %w[given_order content_updated_at content_updated_at_asc title title_desc
                              topics topics_desc districts districts_desc]
      labels = dropdown.css("a").map { |link| link.text.strip }
      expect(labels.last(4)).to eq %w[topics topics_desc districts districts_desc].map { |order|
        I18n.t("custom.municipal_plans.index.orders.#{order}")
      }
      expect(dropdown["selected"]).to eq I18n.t("custom.municipal_plans.index.orders.topics")

      get municipal_plans_path(order: "districts_desc")

      dropdown = document.at_css(".resources-list--filter dropdown-select-menu")
      expect(dropdown["selected"]).to eq I18n.t("custom.municipal_plans.index.orders.districts_desc")
    end

    it "counts the Vorhaben when sorted by Kategorie" do
      plan_with_topics("Mit Kategorie", %w[Bauen])
      plan_with_topics("Ohne Kategorie", [])

      get municipal_plans_path(order: "topics")

      expect(row_titles).to eq ["Mit Kategorie", "Ohne Kategorie"]
      expect(document.at_css("#municipal-plans-sidebar .resources--info-count span:last-child").text.strip)
        .to eq "2"
    end

    it "shows every published plan without pagination" do
      create_list(:municipal_plan, 30, :published, responsible: officer)

      get municipal_plans_path

      expect(document.css(".municipal-plans-table tbody tr").size).to eq 30
      expect(document.at_css(".pagination")).to be_nil
      expect(document.at_css("#municipal-plans-sidebar .resources--info-count span:last-child").text.strip)
        .to eq "30"
    end

    it "shows the count for a search result too" do
      plan

      get municipal_plans_path(search: "Eichplatz")

      expect(response).to have_http_status(:ok)
      expect(row_titles).to eq ["Weiterentwicklung des Eichplatz-Areals"]
      expect(document.at_css("#municipal-plans-sidebar .resources--info-count span:last-child").text.strip)
        .to eq "1"
    end

    def badge_label(badge)
      I18n.t("custom.municipal_plans.badges.#{badge}")
    end

    it "shows the Kennzeichnung as icons with a tooltip each" do
      plan.update_columns(formal_participation: true)

      get municipal_plans_path

      cell = row_for("Weiterentwicklung des Eichplatz-Areals")
        .at_css("td[data-label='#{I18n.t("custom.municipal_plans.index.table.columns.badges")}']")
      tooltips = cell.css("rich-tooltip")
      expect(tooltips.size).to eq 2
      tooltips.zip(%i[new formal_participation]).each do |tooltip, badge|
        trigger = tooltip.at_css("> span")
        expect(trigger["role"]).to eq "img"
        expect(trigger["aria-label"]).to eq badge_label(badge)
        expect(trigger["tabindex"]).to eq "0"
        expect(trigger.at_css("i.fas.fa-#{MunicipalPlans::BadgesComponent::ICONS[badge]}[aria-hidden=true]"))
          .to be_present
        expect(trigger.at_css(".municipal-plans-table--badge-label[aria-hidden=true]").text.strip)
          .to eq badge_label(badge)
        expect(tooltip.at_css("> template").inner_html.strip).to eq badge_label(badge)
      end
    end

    it "lists every kind of Kennzeichnung in the legend above the table" do
      plan

      get municipal_plans_path

      legend = document.at_css(".municipal-plans-table > .municipal-plans-table--legend")
      list = legend.at_css("ul")
      expect(list["aria-label"]).to eq I18n.t("custom.municipal_plans.index.table.legend")
      expect(list.css("li").map { |item| item.text.strip })
        .to eq MunicipalPlans::BadgesComponent::ICONS.keys.map { |badge| badge_label(badge) }
      expect(list.css("i.fas[aria-hidden=true]").size).to eq 4
      expect(legend.next_element["class"]).to eq "municipal-plans-table--scroll"
    end

    def tile_for_plan
      document.at_css(".resources-list--body .municipal_plan-list-item")
    end

    it "shows no participation badges on the tile" do
      plan.update_columns(formal_participation: true, informal_participation: true)

      get municipal_plans_path

      tile = tile_for_plan
      expect(tile.css("rich-tooltip")).to be_empty
      expect(tile.css("ul.no-bullet")).to be_empty
      expect(tile.text).not_to include(badge_label(:formal_participation))
      expect(tile.text).not_to include(badge_label(:informal_participation))
    end

    def updated_on_label(date)
      I18n.t("custom.municipal_plans.index.updated_on", date: date.strftime("%d.%m.%Y"))
    end

    it "shows the content update date in the tile header" do
      plan.update_columns(created_at: 60.days.ago, content_updated_at: Date.new(2026, 3, 14))

      get municipal_plans_path

      expect(tile_for_plan.at_css(".resource-item--header").text.strip)
        .to eq updated_on_label(Date.new(2026, 3, 14))
    end

    it "falls back to the creation date in the tile header without a content update date" do
      plan.update_columns(created_at: Time.zone.local(2026, 2, 3, 10), content_updated_at: nil)

      get municipal_plans_path

      expect(tile_for_plan.at_css(".resource-item--header").text.strip)
        .to eq updated_on_label(Date.new(2026, 2, 3))
    end

    it "renders a header on every tile, in the archive too" do
      plan.update_columns(created_at: 60.days.ago, content_updated_at: Date.current - 60.days)
      create(:municipal_plan, :published, responsible: officer).update!(status: "archived")

      [municipal_plans_path, archive_municipal_plans_path].each do |path|
        get path

        tiles = document.css(".resources-list--body .municipal_plan-list-item")
        expect(tiles).not_to be_empty
        tiles.each do |tile|
          expect(tile.at_css(".resource-item--header")).to be_present
          expect(tile["class"].split).not_to include "-no-header"
        end
      end
    end

    it "offers a footer button to the plan on the tile" do
      plan

      get municipal_plans_path

      button = tile_for_plan.at_css(".resource-item--footer a.button.-grey")
      expect(button.text.strip).to eq I18n.t("custom.municipal_plans.index.to_municipal_plan")
      expect(button["href"]).to eq municipal_plan_path(plan)
      expect(button["tabindex"]).to eq "-1"
      expect(button["aria-hidden"]).to eq "true"
    end

    it "renders the table in the archive too" do
      create(:municipal_plan, :published, responsible: officer, title: "Abgeschlossenes Vorhaben")
        .update!(status: "archived")

      get archive_municipal_plans_path

      expect(row_titles).to eq ["Abgeschlossenes Vorhaben"]
      expect(document.at_css(".municipal-plans-table caption").text.strip)
        .to eq I18n.t("custom.municipal_plans.index.table.archive_caption")
    end

    it "renders the table without the cookie too, next to the list, for CSS to switch" do
      cookies.delete("wide_resources")
      plan

      get municipal_plans_path

      expect(document.at_css(".resources-list.-wide")).to be_nil
      expect(document.at_css(".resources-list .municipal-plans-table + .resources-list--body")).to be_present
      expect(row_titles).to eq ["Weiterentwicklung des Eichplatz-Areals"]
      expect(document.css(".resources-list--inner .resource-item--title").map { |t| t.text.strip })
        .to eq ["Weiterentwicklung des Eichplatz-Areals"]
    end

    it "renders no table when the list is empty" do
      get municipal_plans_path

      expect(document.at_css(".resources-list.-wide")).to be_present
      expect(document.at_css("table")).to be_nil
      expect(document.at_css(".resources-list--body")).to be_present
    end
  end

  describe "the page layout" do
    before { enable_module(true) }

    def document
      Nokogiri::HTML(response.body)
    end

    def hidden_values(form, name)
      form.css("input[type=hidden][name='#{name}']").map { |input| input["value"] }
    end

    it "keeps the ticked filters when searching from the list toolbar" do
      district = create(:registered_address_district, name: "Lobeda")
      topic = create(:municipal_plan_topic)

      get municipal_plans_path(districts: [district.id], topics: [topic.id], order: "title")

      search_form = document.at_css(".resources-list .text-search-form")

      expect(hidden_values(search_form, "districts[]")).to eq [district.id.to_s]
      expect(hidden_values(search_form, "topics[]")).to eq [topic.id.to_s]
      expect(hidden_values(search_form, "order")).to eq ["title"]
    end

    it "keeps the search term when the filters are applied" do
      get municipal_plans_path(search: "Eichplatz")

      filter_form = document.at_css(".municipal-plans-filter-form")

      expect(hidden_values(filter_form, "search")).to eq ["Eichplatz"]
      expect(document.at_css("#municipal-plans-sidebar input[type=text][name=search]")).to be_nil
    end

    it "shows the empty text once when nothing matches" do
      get municipal_plans_path(search: "gibt es nicht")

      expect(response.body.scan(I18n.t("custom.municipal_plans.index.empty_list_text")).size).to eq 1
    end

    it "shows no empty text under a filled list" do
      plan

      get municipal_plans_path

      expect(document.css(".resources-list--inner .resource-item")).not_to be_empty
      expect(response.body).not_to include(I18n.t("custom.municipal_plans.index.empty_list_text"))
    end

    it "renders the intro and the sidebar information as editable content blocks" do
      get municipal_plans_path

      expect(response.body).to include(I18n.t("custom.municipal_plans.index.intro_text"))
      expect(document.at_css("#municipal-plans-sidebar").text)
        .to include(I18n.t("custom.municipal_plans.index.sidebar_information"))
      expect(SiteCustomization::ContentBlock.where(key: %w[municipal_plans_index_welcome
                                                           municipal_plans_index_sidebar]).count).to eq 2
    end

    it "uses its own content block for the archive intro" do
      get archive_municipal_plans_path

      expect(response.body).to include(I18n.t("custom.municipal_plans.index.archive_intro_text"))
      expect(SiteCustomization::ContentBlock.exists?(key: "municipal_plans_archive_welcome")).to be true
    end

    it "places the map across the full width, outside the list and sidebar row" do
      district = create(:registered_address_district, name: "Lobeda")
      create(:map_location, mappable: district, features: {
        "type" => "FeatureCollection",
        "features" => [{ "type" => "Feature", "properties" => {}, "geometry" => {
          "type" => "Polygon",
          "coordinates" => [[[11.58, 50.92], [11.60, 50.92], [11.60, 50.94], [11.58, 50.92]]]
        }}]
      })

      get municipal_plans_path

      expect(document.at_css("main > .js-municipal-plans-map")).to be_present
      expect(document.at_css(".flex-layout .js-municipal-plans-map")).to be_nil
    end
  end

  describe "the hero on the detail page" do
    before { enable_module(true) }

    def hero
      Nokogiri::HTML(response.body).at_css(".municipal-plan-hero")
    end

    def status_chip
      hero.at_css(".municipal-plan-hero--chip.-status")
    end

    def meta_items
      hero.css(".municipal-plan-hero--meta li").map { |item| item.text.squish }
    end

    it "shows the title as the h1, outside the main column" do
      get municipal_plan_path(plan)

      expect(hero.at_css("h1").text.strip).to eq plan.title
      expect(hero.ancestors(".main-column")).to be_empty
    end

    it "marks a newly added Vorhaben as new" do
      plan.update_columns(created_at: 2.days.ago, content_updated_at: Date.current)

      get municipal_plan_path(plan)

      expect(status_chip.text.strip).to eq I18n.t("custom.municipal_plans.show.hero.status_new")
    end

    it "marks a recently updated Vorhaben as updated" do
      plan.update_columns(created_at: 90.days.ago, content_updated_at: Date.current - 5.days)

      get municipal_plan_path(plan)

      expect(status_chip.text.strip).to eq I18n.t("custom.municipal_plans.show.hero.status_updated")
    end

    it "marks an archived Vorhaben as completed, even when it is recent" do
      plan.update_columns(status: "archived", created_at: 2.days.ago, content_updated_at: Date.current)

      get municipal_plan_path(plan)

      expect(status_chip.text.strip).to eq I18n.t("custom.municipal_plans.show.hero.status_archived_chip")
    end

    it "shows no status chip for an older Vorhaben without a recent update" do
      plan.update_columns(created_at: 90.days.ago, content_updated_at: Date.current - 60.days)

      get municipal_plan_path(plan)

      expect(status_chip).to be_nil
    end

    it "links every Thema alphabetically to the filtered list" do
      plan.topic_assignments.destroy_all
      topics = %w[Mobilität Bauen].map do |name|
        create(:municipal_plan_topic, name: name).tap do |topic|
          plan.topic_assignments.create!(topic: topic)
        end
      end

      get municipal_plan_path(plan)

      links = hero.css(".municipal-plan-hero--topics a")

      expect(links.map { |link| link.text.strip }).to eq %w[Bauen Mobilität]
      expect(links.map { |link| link["href"] }).to eq [
        municipal_plans_path(topics: [topics.last.id]),
        municipal_plans_path(topics: [topics.first.id])
      ]
      expect(links.map { |link| link["rel"] }.uniq).to eq ["nofollow"]
    end

    it "shows the Ortsteile, the update date and the version in the meta row" do
      plan.district_assignments.destroy_all
      %w[Zwätzen Lobeda].each do |name|
        plan.district_assignments.create!(district: create(:registered_address_district, name: name))
      end
      plan.update_columns(content_updated_at: Date.new(2026, 3, 14), version: "1.2")

      get municipal_plan_path(plan)

      expect(meta_items).to eq [
        "#{I18n.t("custom.municipal_plans.show.banner.districts")}: Lobeda, Zwätzen",
        I18n.t("custom.municipal_plans.show.updated_on", date: "14.03.2026"),
        "#{I18n.t("custom.municipal_plans.show.banner.version")} 1.2"
      ]
    end

    it "falls back to the creation date and leaves out a missing version" do
      plan.update_columns(created_at: Time.zone.local(2026, 2, 3, 10), content_updated_at: nil, version: "")

      get municipal_plan_path(plan)

      expect(meta_items).to include I18n.t("custom.municipal_plans.show.updated_on", date: "03.02.2026")
      expect(hero.css(".municipal-plan-hero--meta .fa-hashtag")).to be_empty
    end
  end

  describe "the content blocks on the detail page" do
    before { enable_module(true) }

    def document
      Nokogiri::HTML(response.body)
    end

    def show_key(key)
      I18n.t("custom.municipal_plans.show.#{key}")
    end

    def clear_translated(*fields)
      plan.translations.update_all(fields.index_with("<p> </p>"))
    end

    describe "Worum es geht" do
      it "shows the Kurze Beschreibung under its own heading" do
        plan.update!(short_description: "<p>Neubau einer Brücke</p>")

        get municipal_plan_path(plan)

        intro = document.at_css(".municipal-plan-intro")

        expect(intro.at_css("h2").text.strip).to eq show_key("intro.title")
        expect(intro.text).to include "Neubau einer Brücke"
      end

      it "is left out when the Kurze Beschreibung is empty" do
        clear_translated(:short_description)

        get municipal_plan_path(plan)

        expect(document.at_css(".municipal-plan-intro")).to be_nil
      end
    end

    describe "Wo steht das Vorhaben?" do
      def stations
        document.css(".municipal-plan-timeline--station")
      end

      def station_labels
        stations.map { |station| station.at_css("h3").children.first.text.strip }
      end

      it "lists the three stations in order and marks the current one" do
        plan.update!(last_resolution: "Beschluss vom 16.11.2022",
                     processing_status: "Satzung beschlossen",
                     next_steps: "Vorentwurf folgt")

        get municipal_plan_path(plan)

        expect(document.at_css(".municipal-plan-timeline h2").text.strip).to eq show_key("timeline.title")
        expect(document.at_css(".municipal-plan-timeline ol")).to be_present
        expect(station_labels)
          .to eq [show_key("last_resolution"), show_key("processing_status"), show_key("next_steps")]

        current = stations.select { |station| station["aria-current"] == "step" }

        expect(current.size).to eq 1
        expect(current.first.text).to include "Satzung beschlossen"
        expect(current.first.at_css(".municipal-plan-timeline--now").text.strip)
          .to eq show_key("timeline.now")
        expect(document.css(".municipal-plan-timeline--now").size).to eq 1
        expect(stations.css("i").map { |icon| icon.ancestors("[aria-hidden='true']").any? }.uniq).to eq [true]
      end

      it "shows the update date, falling back to the creation date" do
        plan.update_columns(created_at: Time.zone.local(2026, 2, 3, 10), content_updated_at: nil)

        get municipal_plan_path(plan)

        expect(document.at_css(".municipal-plan-timeline--updated").text.strip)
          .to eq I18n.t("custom.municipal_plans.show.updated_on", date: "03.02.2026")
      end

      it "leaves out an empty station" do
        plan.update!(last_resolution: "", processing_status: "Satzung beschlossen")
        clear_translated(:next_steps)

        get municipal_plan_path(plan)

        expect(station_labels).to eq [show_key("processing_status")]
      end

      it "shows no JETZT pill when the Bearbeitungsstand is empty" do
        plan.update!(last_resolution: "Beschluss vom 16.11.2022", next_steps: "Vorentwurf folgt")
        clear_translated(:processing_status)

        get municipal_plan_path(plan)

        expect(station_labels).to eq [show_key("last_resolution"), show_key("next_steps")]
        expect(document.css(".municipal-plan-timeline--now")).to be_empty
      end

      it "is left out when all three fields are empty" do
        clear_translated(:last_resolution, :processing_status, :next_steps)

        get municipal_plan_path(plan)

        expect(document.at_css(".municipal-plan-timeline")).to be_nil
      end
    end

    describe "Weitere Informationen zum Vorhaben" do
      it "shows the text with simple_format under the Hintergrund heading" do
        plan.update!(further_information: "Erster Absatz\n\nZweiter Absatz")

        get municipal_plan_path(plan)

        block = document.at_css(".municipal-plan-background")

        expect(block.at_css(".municipal-plan-block--eyebrow").text.strip).to eq show_key("background.eyebrow")
        expect(block.at_css("h2").text.strip).to eq show_key("background.title")
        expect(block.css(".municipal-plan-block--text p").map { |p| p.text.strip })
          .to eq ["Erster Absatz", "Zweiter Absatz"]
      end

      it "is left out when the field is empty" do
        plan.update!(further_information: "")

        get municipal_plan_path(plan)

        expect(document.at_css(".municipal-plan-background")).to be_nil
      end
    end

    describe "Bürgerbeteiligung" do
      def rows
        document.css(".municipal-plan-participation--row")
      end

      it "always shows both kinds, with Nein when neither applies" do
        plan.update!(formal_participation: false, informal_participation: false)

        get municipal_plan_path(plan)

        expect(document.at_css(".municipal-plan-participation h2").text.strip).to eq show_key("participation")
        expect(rows.map { |row| row.at_css("h3").text.strip })
          .to eq [show_key("participation_block.formal"), show_key("participation_block.informal")]
        expect(rows.map { |row| row.at_css(".municipal-plan-participation--status").text.strip })
          .to eq [show_key("participation_block.status_no")] * 2
        expect(document.css(".municipal-plan-participation--reason")).to be_empty
      end

      it "shows Ja or Nein per kind together with its reason" do
        plan.update!(formal_participation: true, formal_participation_reason: "Im Zuge des Planverfahrens",
                     informal_participation: false, informal_participation_reason: "Keine Gründe erkennbar")

        get municipal_plan_path(plan)

        expect(rows.map { |row| row.at_css(".municipal-plan-participation--status").text.strip })
          .to eq [show_key("participation_block.status_yes"), show_key("participation_block.status_no")]
        expect(rows.map { |row| row.at_css(".municipal-plan-participation--reason").text.strip })
          .to eq ["Im Zuge des Planverfahrens", "Keine Gründe erkennbar"]
      end
    end

    describe "Lage" do
      def section
        document.at_css("section.municipal-plan-location")
      end

      it "shows the map under its own heading with the approximated address below it" do
        plan.map_location.update_column(:approximated_address, "Kleinromstedter Weg, 07751 Jena-Isserstedt")

        get municipal_plan_path(plan)

        heading = section.at_css("h2")

        expect(heading.text.strip).to eq show_key("location.title")
        expect(section["aria-labelledby"]).to eq heading["id"]
        expect(section.at_css(".municipal-plan-location--card .map_location")).to be_present
        expect(section.at_css(".municipal-plan-location--label").text.strip)
          .to eq show_key("location.approximate")
        expect(section.at_css(".municipal-plan-location--address").text.strip)
          .to eq "Kleinromstedter Weg, 07751 Jena-Isserstedt"
      end

      it "says that no address is available when the location has none" do
        plan.map_location.update_column(:approximated_address, nil)

        get municipal_plan_path(plan)

        expect(section.at_css(".municipal-plan-location--address").text.strip)
          .to eq show_key("map_address_missing")
      end

      it "is left out when the Vorhaben has no location" do
        plan.map_location.destroy!

        get municipal_plan_path(plan)

        expect(section).to be_nil
        expect(document.at_css(".main-column .map_location")).to be_nil
      end
    end

    it "orders the blocks and leaves the Kosten out of the main column" do
      plan.update!(further_information: "Hintergrundtext", costs: "ca. 50.000 €")

      get municipal_plan_path(plan)

      headings = document.css(".main-column h2").map { |heading| heading.text.strip }

      expect(headings.first(5)).to eq [
        show_key("intro.title"), show_key("timeline.title"), show_key("background.title"),
        show_key("participation"), show_key("location.title")
      ]
      expect(document.at_css(".main-column").text).not_to include("ca. 50.000 €")
    end
  end

  describe "the sidebar on the detail page" do
    before { enable_module(true) }

    def document
      Nokogiri::HTML(response.body)
    end

    def show_key(key, **options)
      I18n.t("custom.municipal_plans.show.#{key}", **options)
    end

    def contact_card
      document.at_css(".sidebar .sidebar-contact-person")
    end

    def contact_key(key, **options)
      I18n.t("components.sidebar.contact_person_component.#{key}", **options)
    end

    def card_titled(key)
      document.css(".sidebar .sidebar-card").find do |card|
        card.at_css(".sidebar-card--title-text")&.text&.strip == show_key(key)
      end
    end

    def glance_rows
      card_titled("at_a_glance.title").css(".municipal-plan-glance--row").map do |row|
        [row.at_css("dt").text.strip, row.at_css("dd").text.strip]
      end
    end

    it "orders the cards as in the mockup" do
      plan.update!(contact_name: "Maria Muster")
      plan.links.create!(title: "Beschlussvorlage", url: "https://jena.example/vorlage")
      create(:projekt, name: "Beteiligung Eichplatz", municipal_plan: plan)

      get municipal_plan_path(plan)

      titles = document.css(".sidebar > section").map do |card|
        (card.at_css(".sidebar-card--title-text") || card.at_css("h2")).text.strip
      end

      expect(titles).to eq [
        contact_key("title"), show_key("at_a_glance.title"), show_key("links"),
        show_key("notice_card.title"), show_key("projekt_card.title"), I18n.t("proposals.show.share")
      ]
    end

    describe "Ansprechperson" do
      it "shows the initials, name and role under a heading" do
        plan.update!(contact_name: "Maria Muster", contact_role: "Team Stadtplanung")

        get municipal_plan_path(plan)

        expect(contact_card.at_css("h2").text.strip).to eq contact_key("title")
        expect(contact_card.at_css(".sidebar-contact-person--initials").text.strip).to eq "MM"
        expect(contact_card.at_css(".sidebar-contact-person--name").text.strip).to eq "Maria Muster"
        expect(contact_card.at_css(".sidebar-contact-person--role").text.strip).to eq "Team Stadtplanung"
      end

      it "falls back to a user icon without a name" do
        plan.update!(contact_name: nil, contact_role: "Team Stadtplanung")

        get municipal_plan_path(plan)

        avatar = contact_card.at_css(".sidebar-contact-person--initials")

        expect(avatar.text.strip).to be_empty
        expect(avatar.at_css("i.fa-user")).to be_present
        expect(contact_card.at_css(".sidebar-contact-person--name")).to be_nil
      end

      it "names the e-mail link on its own while showing schreiben" do
        plan.update!(contact_name: "Maria Muster", contact_email: "maria.muster@jena.example")

        get municipal_plan_path(plan)

        link = contact_card.at_css("a[href='mailto:maria.muster@jena.example']")
        label = contact_key("email_to_name", name: "Maria Muster")

        expect(link.at_css(".show-for-sr").text.strip).to eq label
        expect(link.text.squish).to eq "#{label} #{contact_key("write")}"
      end

      it "leaves the card out when no contact field is filled" do
        plan.update!(contact_name: nil, contact_role: nil, contact_phone: nil, contact_email: nil)

        get municipal_plan_path(plan)

        expect(contact_card).to be_nil
      end
    end

    describe "Auf einen Blick" do
      it "lists Gebiet, Kosten, both participation kinds and the Version" do
        plan.district_assignments.destroy_all
        plan.district_assignments.create!(district: create(:registered_address_district, name: "Zwätzen"))
        plan.district_assignments.create!(district: create(:registered_address_district, name: "Lobeda"))
        plan.update!(costs: "ca. 50.000 €", formal_participation: true, informal_participation: false)

        get municipal_plan_path(plan.reload)

        expect(glance_rows).to eq [
          [show_key("at_a_glance.area"), "Lobeda, Zwätzen"],
          [show_key("at_a_glance.costs"), "ca. 50.000 €"],
          [show_key("at_a_glance.formal"), show_key("participation_block.status_yes")],
          [show_key("at_a_glance.informal"), show_key("participation_block.status_no")],
          [show_key("banner.version"), plan.version]
        ]
      end

      it "leaves out the Kosten row when no costs are given" do
        plan.update!(costs: "")

        get municipal_plan_path(plan)

        expect(glance_rows.map(&:first)).not_to include show_key("at_a_glance.costs")
      end
    end

    it "marks every link as external and opening in a new tab" do
      plan.links.create!(title: "Beschlussvorlage", url: "https://jena.example/vorlage")

      get municipal_plan_path(plan)

      link = card_titled("links").at_css("a[href='https://jena.example/vorlage']")

      expect(link["target"]).to eq "_blank"
      expect(link["rel"]).to eq "noopener"
      expect(link.at_css(".municipal-plan-links--title").text.strip).to eq "Beschlussvorlage"
      expect(link.at_css(".show-for-sr").text.strip).to eq show_key("opens_in_new_tab")
      expect(link.at_css("i.fa-external-link-alt")["aria-hidden"]).to eq "true"
    end

    it "points the Fragen oder Hinweise card to the notice form" do
      get municipal_plan_path(plan)

      card = card_titled("notice_card.title")

      expect(card.text).to include show_key("notice_card.text")
      expect(card.at_css("a[href='#municipal-plan-notice-form']").text.strip)
        .to eq show_key("notice_card.button")
    end

    describe "Beteiligungsprojekt" do
      it "links a visible project" do
        projekt = create(:projekt, name: "Beteiligung Eichplatz", municipal_plan: plan)

        get municipal_plan_path(plan)

        card = card_titled("projekt_card.title")
        link = card.at_css("a[href='#{page_path(projekt.page.slug)}']")

        expect(card.text).to include show_key("projekt_card.text")
        expect(link.text.squish)
          .to eq "#{show_key("participation_block.projekt_button")} : Beteiligung Eichplatz"
      end

      it "shows one button per project, named by its title" do
        create(:projekt, name: "Beteiligung Eichplatz", municipal_plan: plan)
        create(:projekt, name: "Beteiligung Inselplatz", municipal_plan: plan)

        get municipal_plan_path(plan)

        expect(card_titled("projekt_card.title").css("a").map { |link| link.text.strip })
          .to match_array ["Beteiligung Eichplatz", "Beteiligung Inselplatz"]
      end

      it "leaves the card out without a visible project" do
        create(:projekt, :deactivated, name: "Deaktivierte Beteiligung", municipal_plan: plan)

        get municipal_plan_path(plan)

        expect(card_titled("projekt_card.title")).to be_nil
      end
    end
  end

  describe "the detail page layout" do
    before { enable_module(true) }

    def document
      Nokogiri::HTML(response.body)
    end

    it "starts with the title as the first heading" do
      plan.update!(processing_status: "<p>Die Entwurfsplanung läuft.</p>")

      get municipal_plan_path(plan)

      first_heading = document.css("main h1, main h2, main h3").first

      expect(first_heading.name).to eq "h1"
      expect(first_heading.text.strip).to eq plan.title
    end

    it "lets the notice link move focus into the form" do
      get municipal_plan_path(plan)

      expect(document.at_css("#municipal-plan-notice-form")["tabindex"]).to eq "-1"
      expect(document.at_css(".sidebar a[href='#municipal-plan-notice-form']")).to be_present
    end

    it "heads the notice form with a titled band and marks the required fields" do
      get municipal_plan_path(plan)

      form = document.at_css("#municipal-plan-notice-form")

      expect(form.at_css(".municipal-plan-notice--header h2").text.strip)
        .to eq I18n.t("custom.municipal_plans.notices.form.title")
      expect(form.at_css("#municipal_plan_notice_email")["required"]).to be_present
      expect(form.at_css("#municipal_plan_notice_body")["required"]).to be_present
      expect(form.at_css("#municipal_plan_notice_name")["required"]).to be_nil
      expect(form.css("label[for='municipal_plan_notice_email']").size).to eq 1
      expect(form.at_css("label[for='municipal_plan_notice_email'] span[aria-hidden='true']").text).to eq "*"
      expect(form.at_css(".municipal-plan-notice--legend").text)
        .to include I18n.t("custom.municipal_plans.notices.form.required_legend")
      expect(form.at_css("input[type=submit]")["value"])
        .to eq I18n.t("custom.municipal_plans.notices.form.submit")
    end

    it "leaves the notice form off an archived Vorhaben" do
      plan.update!(status: "archived")

      get municipal_plan_path(plan)

      expect(document.at_css("#municipal-plan-notice-form")).to be_nil
      expect(document.at_css(".sidebar a[href='#municipal-plan-notice-form']")).to be_nil
    end

    it "links a phone number and leaves a phone note without digits as text" do
      plan.update!(contact_phone: "03641 49-0")

      get municipal_plan_path(plan)

      expect(document.at_css(".sidebar a[href='tel:03641490']")).to be_present

      plan.update!(contact_phone: "über die Zentrale")

      get municipal_plan_path(plan)

      expect(document.css(".sidebar a[href^='tel:']")).to be_empty
      expect(document.at_css(".sidebar").text).to include("über die Zentrale")
    end

    it "keeps the Lage footer out of the print-hidden map wrapper" do
      get municipal_plan_path(plan)

      footer = document.at_css(".municipal-plan-location--footer")

      expect(footer).to be_present
      expect(footer.ancestors(".not-print")).to be_empty
      expect(document.at_css(".municipal-plan-location--map.not-print .map_location")).to be_present
    end

    it "describes the Vorhaben for social media" do
      get municipal_plan_path(plan)

      expect(document.at_css("meta[property='og:title']")["content"]).to eq plan.title
      expect(document.at_css("meta[property='og:url']")["content"]).to eq municipal_plan_url(plan)
    end
  end
end
