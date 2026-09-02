require "rails_helper"

describe "Creating an Anliegen in /adm while AI categorization is on", type: :request do
  let(:manager) { create(:user).tap { |user| DeficiencyReportManager.create!(user: user) } }
  let!(:fallback_category) { create(:deficiency_report_category, given_order: 1, ai_fallback: true) }
  let!(:category) { create(:deficiency_report_category, given_order: 2) }
  let!(:subcategory) { create(:deficiency_report_subcategory, category: category) }

  def scope(key)
    I18n.t("adm.deficiency_reports.deficiency_reports.#{key}")
  end

  def stub_llm_content(content)
    chat = double("chat")
    allow(chat).to receive(:ask).and_return(double("response", content: content))
    allow(Ai::RubyLlmFactory).to receive(:chat_with_json_output)
      .and_return(double("chat_builder", with_instructions: chat))
  end

  def stub_llm_failure(error)
    allow(Ai::RubyLlmFactory).to receive(:chat_with_json_output).and_raise(error)
  end

  def create_params(overrides = {})
    {
      deficiency_report: {
        title: "Laterne defekt",
        description: "Die Straßenlaterne vor Hausnummer 12 ist ausgefallen.",
        map_location_attributes: { latitude: "50.1", longitude: "7.1" }
      }.merge(overrides)
    }
  end

  before do
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
    allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)
    allow(DtApi::Client).to receive(:new).and_raise(StandardError, "no DT API in test")
    allow(Ai::Settings).to receive(:ai_available?).and_return(true)
    set_setting("deficiency_reports.ai_categorization", true)
    set_setting("deficiency_reports.map_location_required", nil)
    create(:deficiency_report_status)
    login_as(manager)
  end

  describe "the hint on the category field" do
    it "tells the case worker that leaving it blank hands over to the AI" do
      get new_adm_deficiency_reports_deficiency_report_path

      expect(response.body).to include(scope("form_fields.hints.category_ai"))
      expect(response.body).not_to include(scope("form_fields.hints.category"))
    end

    it "keeps the plain hint on an existing report, which the AI never re-categorizes" do
      report = create(:deficiency_report, category: category)

      get edit_adm_deficiency_reports_deficiency_report_path(report),
          headers: { "Turbo-Frame" => "deficiency_report_content" }

      expect(response.body).to include(scope("form_fields.hints.category"))
      expect(response.body).not_to include(scope("form_fields.hints.category_ai"))
    end

    it "keeps the plain hint on the creation form while the setting is off" do
      set_setting("deficiency_reports.ai_categorization", false)

      get new_adm_deficiency_reports_deficiency_report_path

      expect(response.body).to include(scope("form_fields.hints.category"))
      expect(response.body).not_to include(scope("form_fields.hints.category_ai"))
    end

    it "keeps the plain hint when no AI provider is configured" do
      allow(Ai::Settings).to receive(:ai_available?).and_return(false)

      get new_adm_deficiency_reports_deficiency_report_path

      expect(response.body).to include(scope("form_fields.hints.category"))
      expect(response.body).not_to include(scope("form_fields.hints.category_ai"))
    end
  end

  describe "saving with the category left blank" do
    it "lets the AI assign main and subcategory" do
      stub_llm_content("category_id" => category.id, "subcategory_id" => subcategory.id,
                       "confidence" => 0.9)

      post adm_deficiency_reports_deficiency_reports_path, params: create_params

      report = DeficiencyReport.last
      expect(report.category).to eq(category)
      expect(report.subcategory).to eq(subcategory)
    end

    it "accepts a blank string from the form the same way as a missing key" do
      stub_llm_content("category_id" => category.id, "subcategory_id" => nil, "confidence" => 0.9)

      post adm_deficiency_reports_deficiency_reports_path,
           params: create_params(deficiency_report_category_id: "")

      expect(DeficiencyReport.last.category).to eq(category)
    end

    it "assigns the fallback category when the AI is not confident" do
      stub_llm_content("category_id" => category.id, "subcategory_id" => subcategory.id,
                       "confidence" => 0.1)

      post adm_deficiency_reports_deficiency_reports_path, params: create_params

      report = DeficiencyReport.last
      expect(report.category).to eq(fallback_category)
      expect(report.subcategory).to be_nil
    end

    it "assigns the fallback category when the AI service is unavailable" do
      stub_llm_failure(StandardError.new("provider down"))

      post adm_deficiency_reports_deficiency_reports_path, params: create_params

      expect(DeficiencyReport.last.category).to eq(fallback_category)
    end

    it "says so in the flash when the report landed in the fallback category" do
      stub_llm_failure(StandardError.new("provider down"))

      post adm_deficiency_reports_deficiency_reports_path, params: create_params

      expect(flash[:notice]).to eq(
        I18n.t("adm.deficiency_reports.deficiency_reports.create.ai_fallback",
               category: fallback_category.name)
      )
    end

    it "keeps the plain success flash when the AI was confident" do
      stub_llm_content("category_id" => category.id, "subcategory_id" => subcategory.id,
                       "confidence" => 0.9)

      post adm_deficiency_reports_deficiency_reports_path, params: create_params

      expect(flash[:notice]).to eq(I18n.t("adm.attribute.create.success"))
    end

    it "still refuses the report when the setting is off and no category was picked" do
      set_setting("deficiency_reports.ai_categorization", false)

      expect do
        post adm_deficiency_reports_deficiency_reports_path, params: create_params
      end.not_to change { DeficiencyReport.count }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "after a save that failed for another reason" do
    def checked_category_in_response
      node = Nokogiri::HTML(response.body)
        .at_css("input[name='deficiency_report[deficiency_report_category_id]'][checked]")

      node && node["value"]
    end

    it "does not leave the AI's guess pre-selected in the re-rendered form" do
      stub_llm_failure(StandardError.new("provider down"))

      post adm_deficiency_reports_deficiency_reports_path, params: create_params(title: "")

      expect(response).to have_http_status(:unprocessable_entity)
      expect(checked_category_in_response).to be_nil
    end

    it "re-classifies on the retry instead of silently keeping the fallback" do
      stub_llm_failure(StandardError.new("provider down"))
      post adm_deficiency_reports_deficiency_reports_path, params: create_params(title: "")

      resubmitted_category = checked_category_in_response

      stub_llm_content("category_id" => category.id, "subcategory_id" => subcategory.id,
                       "confidence" => 0.9)
      post adm_deficiency_reports_deficiency_reports_path,
           params: create_params(deficiency_report_category_id: resubmitted_category)

      expect(DeficiencyReport.last.category).to eq(category)
    end
  end

  describe "saving with a category picked by hand" do
    it "keeps the case worker's choice and never calls the AI" do
      expect(Ai::RubyLlmFactory).not_to receive(:chat_with_json_output)

      post adm_deficiency_reports_deficiency_reports_path,
           params: create_params(deficiency_report_category_id: category.id,
                                 deficiency_report_subcategory_id: subcategory.id)

      report = DeficiencyReport.last
      expect(report.category).to eq(category)
      expect(report.subcategory).to eq(subcategory)
    end
  end

  describe "correcting an existing report" do
    let(:report) { create(:deficiency_report, category: fallback_category) }

    it "saves a new main and subcategory, whatever the report came from" do
      patch adm_deficiency_reports_deficiency_report_path(report),
            params: { deficiency_report: { deficiency_report_category_id: category.id,
                                           deficiency_report_subcategory_id: subcategory.id }}

      report.reload
      expect(report.category).to eq(category)
      expect(report.subcategory).to eq(subcategory)
    end

    it "is not overwritten by the AI on a later save" do
      expect(Ai::RubyLlmFactory).not_to receive(:chat_with_json_output)

      patch adm_deficiency_reports_deficiency_report_path(report),
            params: { deficiency_report: { deficiency_report_category_id: category.id }}
      patch adm_deficiency_reports_deficiency_report_path(report),
            params: { deficiency_report: { title: "Laterne defekt, dringend" }}

      expect(report.reload.category).to eq(category)
    end
  end
end
