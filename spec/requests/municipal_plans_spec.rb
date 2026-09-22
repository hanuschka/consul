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

    it "hides an archived plan" do
      archived = create(:municipal_plan, responsible: officer, status: "archived")

      expect { get municipal_plan_path(archived) }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "lists only published plans on the overview" do
      plan
      create(:municipal_plan, responsible: officer, title: "Noch nicht freigegeben")

      get municipal_plans_path

      expect(response.body).to include("Weiterentwicklung des Eichplatz-Areals")
      expect(response.body).not_to include("Noch nicht freigegeben")
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
end
