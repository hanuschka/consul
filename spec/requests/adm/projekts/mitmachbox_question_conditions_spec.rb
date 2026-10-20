require "rails_helper"

describe "Adm Mitmachbox question display conditions", type: :request do
  let(:admin) { create(:administrator).user }
  let(:projekt_phase) { create(:mitmachbox_phase) }
  let(:questions) do
    [
      { "id" => 1, "position" => 1, "prompt" => "Nutzen Sie die Bibliothek?",
        "question_type" => "single_choice", "required" => false,
        "options" => [{ "id" => 11, "label" => "Ja" }, { "id" => 12, "label" => "Nein" }] },
      { "id" => 2, "position" => 2, "prompt" => "Warum nicht?", "question_type" => "single_choice",
        "required" => false, "options" => [{ "id" => 21, "label" => "Keine Zeit" }],
        "condition" => { "question_id" => 1, "option_ids" => [12] }}
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
  let(:questions_resource) { instance_double(Mitmachbox::Resources::Questions, create: {}, update: {}) }
  let(:client) do
    instance_double(Mitmachbox::Client, surveys: surveys, versions: versions, questions: questions_resource)
  end

  before do
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
    allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)
    allow(Mitmachbox).to receive(:configured?).and_return(true)
    allow(Mitmachbox::Client).to receive(:new).and_return(client)
    login_as(admin)
  end

  def question_params(**extra)
    { question: { prompt: "Neue Frage", question_type: "single_choice", required: "0" }.merge(extra) }
  end

  it "passes on only the options of the chosen earlier question" do
    post adm_projekts_phase_mitmachbox_questions_path(projekt_phase),
         params: question_params(condition_question_id: "1", condition_option_ids: ["12", "21"])

    expect(questions_resource).to have_received(:create)
      .with(7, 30, hash_including(condition_option_ids: [12]))
  end

  it "clears the condition when no question is chosen" do
    patch adm_projekts_phase_mitmachbox_question_path(projekt_phase, 2),
          params: question_params(condition_question_id: "", condition_option_ids: ["12"])

    expect(questions_resource).to have_received(:update)
      .with(7, 30, 2, hash_including(condition_option_ids: []))
  end

  it "explains why a question others depend on cannot be changed" do
    allow(questions_resource).to receive(:update).and_raise(
      Mitmachbox::ConflictError.new(http_status: 409, api_code: "condition_dependency")
    )

    patch adm_projekts_phase_mitmachbox_question_path(projekt_phase, 1),
          params: question_params(question_type: "rating")

    expect(flash[:alert]).to eq I18n.t("adm.projekts.mitmachbox.errors.condition_dependency")
  end

  it "offers only earlier single-choice questions as the condition" do
    get edit_adm_projekts_phase_mitmachbox_question_path(projekt_phase, 2)
    page = Capybara.string(response.body)

    source_label = I18n.t("adm.projekts.mitmachbox.questions.condition_source_option",
                          number: 1, prompt: "Nutzen Sie die Bibliothek?")

    expect(page).to have_select("question[condition_question_id]", with_options: [source_label])
    expect(page).not_to have_css("option", text: "Warum nicht?")
  end
end
