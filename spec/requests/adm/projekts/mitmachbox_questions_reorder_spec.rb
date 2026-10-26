require "rails_helper"

describe "Adm Mitmachbox question reordering", type: :request do
  let(:admin) { create(:administrator).user }
  let(:projekt_phase) { create(:mitmachbox_phase) }
  let(:question_ids) { (101..112).to_a }
  let(:questions) do
    question_ids.each_with_index.map do |id, index|
      { "id" => id, "prompt" => "Frage #{index + 1}", "question_type" => "single_choice",
        "required" => false, "position" => index + 1, "options" => [] }
    end
  end
  let(:survey) do
    { "id" => 7, "title" => "Umfrage", "state" => "draft", "responses_count" => 0,
      "draft_version" => { "id" => 30, "version_number" => 2 }, "current_version" => nil,
      "current_version_id" => nil }
  end

  let(:surveys) { instance_double(Mitmachbox::Resources::Surveys, find: survey) }
  let(:versions) do
    instance_double(Mitmachbox::Resources::Versions, find: { "id" => 30, "questions" => questions })
  end
  let(:questions_resource) { instance_double(Mitmachbox::Resources::Questions, reorder: {}) }
  let(:client) do
    instance_double(Mitmachbox::Client, surveys: surveys, versions: versions, questions: questions_resource)
  end

  before do
    allow(Mitmachbox).to receive(:configured?).and_return(true)
    allow(Mitmachbox::Client).to receive(:new).and_return(client)
    login_as(admin)
  end

  def reorder(ids)
    tree = ids.map { |id| { id: id.to_s, children: [] } }

    patch reorder_adm_projekts_phase_mitmachbox_questions_path(projekt_phase),
          params: { tree: tree }, as: :json
  end

  it "saves question 11 at position 2" do
    dragged = question_ids.dup
    dragged.insert(1, dragged.delete(111))

    reorder(dragged)

    expect(questions_resource).to have_received(:reorder).with(7, 30, question_ids: dragged)
    expect(response).to have_http_status(:ok)
    expect(flash[:notice]).to be_nil
    expect(flash[:alert]).to be_nil
  end

  it "explains a refused order that puts a follow-up above its branching question" do
    allow(questions_resource).to receive(:reorder).and_raise(
      Mitmachbox::ValidationError.new(http_status: 422, api_code: "branch_order_violation")
    )

    reorder(question_ids.reverse)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(flash[:alert]).to eq I18n.t("adm.projekts.mitmachbox.errors.branch_order")
  end

  it "does not save an order built from an outdated question list" do
    reorder(question_ids.first(11))

    expect(questions_resource).not_to have_received(:reorder)
    expect(response).to have_http_status(:unprocessable_entity)
    expect(flash[:alert]).to eq I18n.t("adm.projekts.mitmachbox.errors.stale_order")
  end

  describe "the survey tab" do
    let(:handle) { "tbody[data-controller='sortable'] tr[data-sortable-id] [data-sortable-handle]" }
    let(:reorder_path) { reorder_adm_projekts_phase_mitmachbox_questions_path(projekt_phase) }
    let(:sortable_list) { "tbody[data-sortable-url-value='#{reorder_path}']" }

    before do
      allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
      allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)
    end

    def survey_tab
      get mitmachbox_survey_adm_projekts_phase_path(projekt_phase)
      Capybara.string(response.body)
    end

    it "gives every draft question a drag handle and keeps the keyboard move actions" do
      page = survey_tab

      expect(page).to have_css(handle, count: 12)
      expect(page).to have_css(sortable_list)
      move_first_down = move_down_adm_projekts_phase_mitmachbox_question_path(projekt_phase, 101)
      move_last_up = move_up_adm_projekts_phase_mitmachbox_question_path(projekt_phase, 112)

      expect(page).to have_link(href: move_first_down)
      expect(page).to have_link(href: move_last_up)
    end

    it "shows a published version without drag handles" do
      survey.merge!("state" => "open", "draft_version" => nil,
                    "current_version" => { "id" => 29, "version_number" => 1 }, "current_version_id" => 29)

      page = survey_tab

      expect(page).to have_text("Frage 11")
      expect(page).not_to have_css(handle)
      expect(page).not_to have_css(sortable_list)
    end
  end
end
