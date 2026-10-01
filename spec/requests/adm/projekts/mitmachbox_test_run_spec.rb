require "rails_helper"

describe "Adm Mitmachbox test run", type: :request do
  let(:admin) { create(:administrator).user }
  let(:projekt_phase) { create(:mitmachbox_phase) }
  let(:questions) do
    [
      { "id" => 1, "position" => 1, "prompt" => "Nutzen Sie die Bibliothek?",
        "question_type" => "single_choice", "required" => true,
        "options" => [
          { "id" => 11, "label" => "Ja", "position" => 1, "next_question_id" => 3, "ends_survey" => false },
          { "id" => 12, "label" => "Nein", "position" => 2, "next_question_id" => nil, "ends_survey" => true }
        ] },
      { "id" => 2, "position" => 2, "prompt" => "Wie oft?", "question_type" => "single_choice",
        "required" => false, "options" => [] },
      { "id" => 3, "position" => 3, "prompt" => "Wie zufrieden sind Sie?", "question_type" => "rating",
        "required" => false, "options" => [] }
    ]
  end
  let(:survey) do
    { "id" => 7, "title" => "Umfrage", "state" => "draft", "responses_count" => 0,
      "draft_version" => { "id" => 30, "version_number" => 1 }, "current_version" => nil,
      "current_version_id" => nil }
  end

  let(:surveys) { instance_double(Mitmachbox::Resources::Surveys, find: survey) }
  let(:versions) do
    instance_double(Mitmachbox::Resources::Versions, find: { "id" => 30, "questions" => questions })
  end
  let(:client) { instance_double(Mitmachbox::Client, surveys: surveys, versions: versions) }

  before do
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
    allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)
    allow(Mitmachbox).to receive(:configured?).and_return(true)
    allow(Mitmachbox::Client).to receive(:new).and_return(client)
    login_as(admin)
  end

  def test_run(**params)
    get mitmachbox_test_run_adm_projekts_phase_path(projekt_phase, version: "draft", **params)
    response.body
  end

  def t_run(key)
    I18n.t("adm.projekts.phases.mitmachbox_test_run.#{key}")
  end

  it "runs a draft that has never been published" do
    expect(test_run).to include("Nutzen Sie die Bibliothek?")
    expect(versions).to have_received(:find).with(7, 30)
  end

  it "follows a jump to its target" do
    body = test_run(answered: 1, answers: { "1" => ["11"] })

    expect(body).to include("Wie zufrieden sind Sie?")
    expect(body).not_to include("Wie oft?")
  end

  it "shows the closing screen for an answer that ends the survey" do
    expect(test_run(answered: 1, answers: { "1" => ["12"] })).to include(t_run(:finished))
  end

  it "keeps a required question until an answer is chosen" do
    body = test_run(answered: 1)

    expect(body).to include(t_run(:required))
    expect(body).to include("Nutzen Sie die Bibliothek?")
  end

  it "stores nothing, so results and participation stay unchanged" do
    expect do
      test_run(answered: 1, answers: { "1" => ["11"] })
      test_run(answered: 3, answers: { "1" => ["11"] })
    end.not_to change(MitmachboxParticipation, :count)

    expect(response.body).to include(t_run(:finished))
  end

  it "runs the published version on request" do
    survey.merge!("draft_version" => nil, "current_version" => { "id" => 29, "version_number" => 1 })

    get mitmachbox_test_run_adm_projekts_phase_path(projekt_phase, version: "current")

    expect(versions).to have_received(:find).with(7, 29)
    expect(response.body).to include("Nutzen Sie die Bibliothek?")
  end

  it "is not available to a projekt manager who may not edit the phase" do
    manager = create(:projekt_manager)
    create(:projekt_manager_assignment, :moderate, projekt: projekt_phase.projekt, projekt_manager: manager)
    login_as(manager.user)

    get mitmachbox_test_run_adm_projekts_phase_path(projekt_phase, version: "draft")

    expect(response).to have_http_status(:redirect)
    expect(versions).not_to have_received(:find)
  end

  it "offers the test run on the survey tab" do
    get mitmachbox_survey_adm_projekts_phase_path(projekt_phase)

    expect(Capybara.string(response.body))
      .to have_link(href: mitmachbox_test_run_adm_projekts_phase_path(projekt_phase, version: "draft"))
  end
end
