require "rails_helper"

describe Mitmachbox::PublicSurveyService do
  let(:projekt_phase) { create(:mitmachbox_phase) }
  let(:surveys) { instance_double(Mitmachbox::Resources::Surveys) }
  let(:versions) { instance_double(Mitmachbox::Resources::Versions) }
  let(:client) { instance_double(Mitmachbox::Client, surveys: surveys, versions: versions) }

  let(:survey) do
    { "id" => 7, "state" => "open", "current_version" => { "id" => 42, "version_number" => 3 }}
  end
  let(:version_detail) do
    {
      "questions" => [
        { "id" => 2, "position" => 2, "prompt" => "Second", "options" => [] },
        { "id" => 1, "position" => 1, "prompt" => "First",
          "options" => [
            { "id" => 20, "position" => 2, "label" => "B" },
            { "id" => 10, "position" => 1, "label" => "A" }
          ] }
      ]
    }
  end

  before do
    allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
    allow(Mitmachbox).to receive(:configured?).and_return(true)
    allow(Mitmachbox::Client).to receive(:new).and_return(client)
    allow(surveys).to receive(:find).with(projekt_phase.mitmachbox_survey_id).and_return(survey)
    allow(versions).to receive(:find).with(7, 42).and_return(version_detail)
  end

  it "resolves the current published version with questions and options in order" do
    result = Mitmachbox::PublicSurveyService.call(projekt_phase)

    expect(result["state"]).to eq("open")
    expect(result["survey_id"]).to eq(7)
    expect(result["version_id"]).to eq(42)
    expect(result["questions"].map { |question| question["id"] }).to eq([1, 2])
    expect(result["questions"].first["options"].map { |option| option["id"] }).to eq([10, 20])
  end

  it "caches the payload so a second call performs no further requests" do
    Mitmachbox::PublicSurveyService.call(projekt_phase)

    expect(surveys).not_to receive(:find)
    expect(versions).not_to receive(:find)
    expect(Mitmachbox::PublicSurveyService.call(projekt_phase)["version_id"]).to eq(42)
  end

  it "serves a fresh payload after the cache is expired" do
    Mitmachbox::PublicSurveyService.call(projekt_phase)
    Mitmachbox::PublicSurveyService.expire!(projekt_phase.mitmachbox_survey_id)

    expect(surveys).to receive(:find).and_return(survey)
    expect(versions).to receive(:find).and_return(version_detail)
    Mitmachbox::PublicSurveyService.call(projekt_phase)
  end

  it "returns nil when the survey has no published version" do
    allow(surveys).to receive(:find).and_return(survey.merge("current_version" => nil))

    expect(Mitmachbox::PublicSurveyService.call(projekt_phase)).to be_nil
  end

  it "returns nil and does not raise when the platform errors" do
    allow(surveys).to receive(:find).and_raise(Mitmachbox::Error, "boom")

    expect(Mitmachbox::PublicSurveyService.call(projekt_phase)).to be_nil
  end

  it "does not cache a failed lookup" do
    allow(surveys).to receive(:find).and_raise(Mitmachbox::Error, "boom")
    Mitmachbox::PublicSurveyService.call(projekt_phase)

    allow(surveys).to receive(:find).and_return(survey)
    expect(Mitmachbox::PublicSurveyService.call(projekt_phase)["version_id"]).to eq(42)
  end

  it "returns nil when the phase has no remote survey" do
    projekt_phase.update_columns(mitmachbox_survey_id: nil)

    expect(Mitmachbox::PublicSurveyService.call(projekt_phase)).to be_nil
  end

  it "returns nil when the integration is not configured" do
    allow(Mitmachbox).to receive(:configured?).and_return(false)

    expect(Mitmachbox::PublicSurveyService.call(projekt_phase)).to be_nil
  end
end
