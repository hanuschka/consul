require "rails_helper"

describe "Vorhabenliste", type: :request do
  let(:officer) { create(:municipal_plan_officer) }
  let(:plan) do
    create(:municipal_plan, :published,
           responsible: officer,
           title: "Weiterentwicklung des Eichplatz-Areals",
           internal_notes: "Interner Vermerk der Sachbearbeitung",
           system_mailbox_email: "postfach@jena.example")
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

  describe "remembering the chosen view" do
    before { enable_module(true) }

    it "stores the table view in a cookie and returns to the same list with its filters" do
      get municipal_plans_path(view: "table", districts: ["7"], order: "title")

      query = { districts: ["7"], order: "title" }.to_query
      expect(response).to redirect_to("#{municipal_plans_path}?#{query}")
      expect(cookies["municipal_plans_view"]).to eq "table"
    end

    it "does the same in the archive" do
      get archive_municipal_plans_path(view: "table")

      expect(response).to redirect_to(archive_municipal_plans_path)
      expect(cookies["municipal_plans_view"]).to eq "table"
    end

    it "ignores an unknown view but still drops it from the address" do
      get municipal_plans_path(view: "javascript:alert(1)")

      expect(response).to redirect_to(municipal_plans_path)
      expect(cookies["municipal_plans_view"]).to be_blank
    end

    it "switches back to the tiles" do
      get municipal_plans_path(view: "table")
      get municipal_plans_path(view: "tiles")

      expect(cookies["municipal_plans_view"]).to eq "tiles"
    end
  end

  describe "the table view" do
    before do
      enable_module(true)
      cookies["municipal_plans_view"] = "table"
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

    it "renders a table with five column headers and the linked name" do
      plan

      get municipal_plans_path

      expect(document.css("table thead th[scope=col]").size).to eq 5
      expect(document.css(".resources-list--inner")).to be_empty
      link = row_for("Weiterentwicklung des Eichplatz-Areals").at_css("a")
      expect(link["href"]).to eq municipal_plan_path(plan)
    end

    it "keeps the table semantics as explicit ARIA roles" do
      plan

      get municipal_plans_path

      table = document.at_css("table[role=table]")
      caption = table.at_css("caption")
      expect(table["aria-labelledby"]).to eq caption["id"]
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
    end

    it "renders the table in the archive too" do
      create(:municipal_plan, :published, responsible: officer, title: "Abgeschlossenes Vorhaben")
        .update!(status: "archived")

      get archive_municipal_plans_path

      expect(row_titles).to eq ["Abgeschlossenes Vorhaben"]
    end
  end

  describe "the view switch" do
    before { enable_module(true) }

    it "links to the table with the current filters and replaces the wide-mode button" do
      plan

      get municipal_plans_path(districts: ["7"], order: "title", page: 2)

      document = Nokogiri::HTML(response.body)
      group = document.at_css(".resources-view-switch[role=group]")
      table_text = I18n.t("custom.municipal_plans.index.view_switch.table")
      table_link = group.css("a").find { |link| link.text.strip == table_text }
      query = Rack::Utils.parse_nested_query(URI.parse(table_link["href"]).query)

      expect(URI.parse(table_link["href"]).path).to eq municipal_plans_path
      expect(query).to eq("districts" => ["7"], "order" => "title", "view" => "table")
      expect(group.at_css("[aria-current=true]").text.strip)
        .to eq I18n.t("custom.municipal_plans.index.view_switch.tiles")
      expect(document.at_css(".js-resource-list-switch-view-button")).to be_nil
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

    it "shows no empty text under a filled table" do
      plan
      cookies["municipal_plans_view"] = "table"

      get municipal_plans_path

      expect(document.css("table tbody tr")).not_to be_empty
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
