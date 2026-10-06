require "rails_helper"

describe "Adm Mitmachbox survey tab", type: :request do
  let(:admin) { create(:administrator).user }
  let(:projekt_phase) { create(:mitmachbox_phase) }
  let(:current_questions) do
    [{ "id" => 1, "position" => 1, "prompt" => "Nutzen Sie die Bibliothek?",
       "question_type" => "single_choice", "required" => true, "options" => [] }]
  end
  let(:draft_questions) do
    [{ "id" => 2, "position" => 1, "prompt" => "Wie oft kommen Sie hierher?",
       "question_type" => "single_choice", "required" => false, "options" => [] }]
  end
  let(:current_version) { { "id" => 29, "version_number" => 3 } }
  let(:draft_version) { { "id" => 30, "version_number" => 4 } }
  let(:state) { "open" }
  let(:survey) do
    { "id" => 7, "title" => "Umfrage", "state" => state, "responses_count" => 29,
      "draft_version" => draft_version, "current_version" => current_version,
      "current_version_id" => current_version&.fetch("id") }
  end
  let(:surveys) { instance_double(Mitmachbox::Resources::Surveys, find: survey) }
  let(:versions) { instance_double(Mitmachbox::Resources::Versions) }
  let(:client) { instance_double(Mitmachbox::Client, surveys: surveys, versions: versions) }

  before do
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
    allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)
    allow(Mitmachbox).to receive(:configured?).and_return(true)
    allow(Mitmachbox::Client).to receive(:new).and_return(client)
    allow(versions).to receive(:find).with(7, 29).and_return("id" => 29, "questions" => current_questions)
    allow(versions).to receive(:find).with(7, 30).and_return("id" => 30, "questions" => draft_questions)
    login_as(admin)
  end

  def tab
    get mitmachbox_survey_adm_projekts_phase_path(projekt_phase)
    Capybara.string(response.body)
  end

  def t_tab(key, **options)
    I18n.t("adm.projekts.phases.mitmachbox_survey.#{key}", **options)
  end

  def test_run_path(version)
    mitmachbox_test_run_adm_projekts_phase_path(projekt_phase, version: version)
  end

  context "while a draft exists next to the published version" do
    it "keeps the published version, its questions and its test run on the tab" do
      page = tab

      expect(page).to have_text(t_tab("current_section_title", number: 3))
      expect(page).to have_css("details", text: "Nutzen Sie die Bibliothek?", visible: :all)
      expect(page).to have_link(href: test_run_path("current"))

      expect(page).to have_text(t_tab("draft_section_title", number: 4))
      expect(page).to have_text("Wie oft kommen Sie hierher?")
      expect(page).to have_link(href: test_run_path("draft"))
    end

    it "explains every action without a click and says which level it affects" do
      page = tab

      expect(page).to have_text(t_tab("survey_scope_pill"))
      expect(page).to have_text(t_tab("status_row_text"))
      expect(page).to have_text(t_tab("current_row_text"))
      expect(page).to have_text(t_tab("draft_scope_pill"))
      expect(page).to have_text(t_tab("draft_row_text"))
      expect(page).to have_text(t_tab("publish_row_text"))
      expect(page).to have_text(t_tab("archive_row_text"))
    end

    it "does not offer a new draft while one exists" do
      expect(tab).not_to have_css("button", text: t_tab("new_draft_button"))
    end

    it "warns before publishing that the running version is replaced during collection" do
      page = tab
      publish_path = mitmachbox_publish_draft_adm_projekts_phase_path(projekt_phase)
      confirm = page.find("form[action='#{publish_path}']")["data-turbo-confirm"]

      expect(confirm).to include(t_tab("publish_confirm_replace", draft: 4, current: 3))
      expect(confirm).to include(t_tab("publish_confirm_while_open"))
    end
  end

  context "with an empty draft" do
    let(:draft_questions) { [] }

    it "does not offer to publish it" do
      page = tab

      publish_path = mitmachbox_publish_draft_adm_projekts_phase_path(projekt_phase)

      expect(page).not_to have_text(t_tab("publish_row_text"))
      expect(page).not_to have_css("form[action='#{publish_path}']")
    end
  end

  context "without a draft" do
    let(:draft_version) { nil }

    it "offers a new draft from the published version" do
      page = tab

      expect(page).to have_css("button", text: t_tab("new_draft_button"))
      expect(page).to have_link(href: test_run_path("current"))
      expect(page).not_to have_link(href: test_run_path("draft"))
    end
  end

  it "separates archiving from closing and says it cannot be undone" do
    page = tab

    expect(page).to have_text(t_tab("end_section_title"))
    expect(page).to have_text(t_tab("end_scope_pill"))
    expect(page).to have_text(t_tab("archive_row_text"))
    expect(page).to have_css("button", text: t_tab("close_button"))
    expect(page).to have_css("button", text: t_tab("archive_button"))
  end

  context "when the survey is closed" do
    let(:state) { "closed" }

    it "offers to reopen with an icon other than the test run's" do
      page = tab
      reopen_icon = page.find("button", text: t_tab("reopen_button")).find(".material-symbols-outlined").text

      expect(page).to have_text(t_tab("status_badges.closed"))
      expect(reopen_icon).not_to eq "visibility"
    end

    context "without a published version" do
      let(:current_version) { nil }

      it "disables reopening and explains why" do
        page = tab

        expect(page).to have_css("button[disabled]", text: t_tab("reopen_button"))
        expect(page).to have_text(t_tab("open_requires_published_hint"))
      end
    end
  end

  context "before the first version is published" do
    let(:state) { "draft" }
    let(:current_version) { nil }

    it "gives the test run a different icon than opening the survey" do
      page = tab
      test_run_icon = page.find("a[href='#{test_run_path("draft")}'] .material-symbols-outlined").text
      open_icon = page.find("button", text: t_tab("open_button")).find(".material-symbols-outlined").text

      expect(test_run_icon).to eq "visibility"
      expect(open_icon).not_to eq test_run_icon
    end

    it "shows the survey as not yet opened and explains why it cannot be opened" do
      page = tab

      expect(page).to have_text(t_tab("status_badges.draft"))
      expect(page).to have_css("button[disabled]", text: t_tab("open_button"))
      expect(page).to have_text(t_tab("open_requires_published_hint"))
      expect(page).not_to have_text(t_tab("current_row_title"))
    end

    it "warns that the first version goes live once the survey is opened" do
      publish_path = mitmachbox_publish_draft_adm_projekts_phase_path(projekt_phase)
      confirm = tab.find("form[action='#{publish_path}']")["data-turbo-confirm"]

      expect(confirm).to include(t_tab("publish_confirm_first", draft: 4))
      expect(confirm).not_to include(t_tab("publish_confirm_while_open"))
    end
  end

  context "when the survey is archived" do
    let(:state) { "archived" }

    it "shows the archived status and no further archive action" do
      page = tab

      expect(page).to have_text(t_tab("status_badges.archived"))
      expect(page).not_to have_css("button", text: t_tab("archive_button"))
      expect(page).not_to have_text(t_tab("end_section_title"))
    end
  end
end
