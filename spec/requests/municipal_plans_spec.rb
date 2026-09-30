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

      banner = Nokogiri::HTML(response.body).at_css(".resource-page-banner")

      expect(banner.at_css("a[href='#{page_path(active.page.slug)}']").text)
        .to include(I18n.t("custom.resource_page.banner_component.related_projekt"))
      expect(response.body).to include("Beteiligung Eichplatz")
      expect(response.body).not_to include("Deaktivierte Beteiligung")
      expect(response.body).not_to include("Gelöschte Beteiligung")
    end

    it "shows no related-project row when no project is linked" do
      get municipal_plan_path(plan)

      expect(Nokogiri::HTML(response.body).css(".resource-page-banner .fa-code-branch")).to be_empty
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

    it "links a phone number and leaves a phone note without digits as text" do
      plan.update!(contact_phone: "03641 49-0")

      get municipal_plan_path(plan)

      expect(document.at_css(".sidebar a[href='tel:03641490']")).to be_present

      plan.update!(contact_phone: "über die Zentrale")

      get municipal_plan_path(plan)

      expect(document.css(".sidebar a[href^='tel:']")).to be_empty
      expect(document.at_css(".sidebar").text).to include("über die Zentrale")
    end

    it "keeps the address sentence out of the print-hidden map wrapper" do
      get municipal_plan_path(plan)

      sentence = I18n.t("custom.municipal_plans.show.map_address_missing")
      paragraph = document.css("main p").find { |node| node.text.strip == sentence }

      expect(paragraph).to be_present
      expect(paragraph.ancestors(".not-print")).to be_empty
    end

    it "describes the Vorhaben for social media" do
      get municipal_plan_path(plan)

      expect(document.at_css("meta[property='og:title']")["content"]).to eq plan.title
      expect(document.at_css("meta[property='og:url']")["content"]).to eq municipal_plan_url(plan)
    end
  end
end
