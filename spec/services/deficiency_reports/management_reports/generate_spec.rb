require "rails_helper"

describe DeficiencyReports::ManagementReports::Generate do
  def stub_llm_content(content)
    chat = double("chat")
    allow(chat).to receive(:ask).and_return(RubyLLM::Message.new(role: :assistant, content: content.to_json))
    allow(Ai::RubyLlmFactory).to receive(:chat_with_json_output)
      .and_return(double("chat_builder", with_instructions: chat))
    chat
  end

  let!(:open_status) { create(:deficiency_report_status) }
  let(:closed_status) { create(:deficiency_report_status, archive_reports: true) }
  let(:street_lights) { create(:deficiency_report_category, name: "Straßenbeleuchtung") }
  let(:waste) { create(:deficiency_report_category, name: "Müll") }
  let(:profile) do
    create(:deficiency_report_report_profile, building_blocks: %w[incoming_and_closed top_categories])
  end
  let(:report) do
    DeficiencyReport::ManagementReport.create!(
      report_profile: profile, profile_name: profile.name, building_blocks: profile.building_blocks,
      period_start: 7.days.ago, period_end: Time.current
    )
  end

  before do
    allow(DtApi::Client).to receive(:new).and_raise(StandardError, "no DT API in test")
    allow(Ai::Settings).to receive(:ai_available?).and_return(true)
  end

  describe "figures" do
    before do
      create_list(:deficiency_report, 2, category: street_lights)
      create(:deficiency_report, category: waste)
      create(:deficiency_report, category: waste, created_at: 10.days.ago)
      create(:deficiency_report, category: waste, created_at: 10.days.ago)
        .update!(status: closed_status, status_changed_at: 1.day.ago)
    end

    it "counts the reports of the period from the data" do
      figures = DeficiencyReports::ManagementReports::Figures.call(profile, report.period, profile.building_blocks)

      expect(figures["incoming_and_closed"]).to eq("incoming" => 3, "closed" => 1)
      expect(figures["top_categories"]).to eq [{ "name" => "Straßenbeleuchtung", "count" => 2 },
                                               { "name" => "Müll", "count" => 1 }]
    end

    it "only counts reports of the profile's categories" do
      profile.update!(category_ids: [waste.id])

      figures = DeficiencyReports::ManagementReports::Figures.call(profile, report.period, profile.building_blocks)

      expect(figures["incoming_and_closed"]).to eq("incoming" => 1, "closed" => 1)
      expect(figures["top_categories"]).to eq [{ "name" => "Müll", "count" => 1 }]
    end

    it "computes only the selected building blocks" do
      figures = DeficiencyReports::ManagementReports::Figures.call(profile, report.period, profile.building_blocks)

      expect(figures.keys).to eq %w[incoming_and_closed top_categories]
    end
  end

  describe "officer group filter" do
    it "includes reports of the group and of officers in the group" do
      group = create(:deficiency_report_officer_group)
      member = create(:deficiency_report_officer)
      group.officers << member
      outsider = create(:deficiency_report_officer)

      by_group = create(:deficiency_report, responsible: group)
      by_member = create(:deficiency_report, responsible: member)
      create(:deficiency_report, responsible: outsider)
      create(:deficiency_report)

      profile.update!(officer_group_ids: [group.id])

      expect(profile.deficiency_reports).to match_array [by_group, by_member]
    end
  end

  describe "a successful run" do
    let!(:light_report) { create(:deficiency_report, category: street_lights, title: "Laterne defekt") }
    let!(:waste_report) { create(:deficiency_report, category: waste, title: "Sperrmüll am Weg") }

    it "stores the figures and the summary, keeping only selected blocks and known reports" do
      stub_llm_content(
        "sections" => [
          { "building_block" => "incoming_and_closed",
            "statements" => [{ "text" => "Der Eingang war ruhig.", "report_ids" => [light_report.id, 999_999] }] },
          { "building_block" => "notable_items",
            "statements" => [{ "text" => "Nicht angefordert.", "report_ids" => [] }] }
        ]
      )

      described_class.call(report)

      expect(report.reload).to be_completed
      expect(report.figures["incoming_and_closed"]).to eq("incoming" => 2, "closed" => 0)
      expect(report.sections).to eq [
        { "building_block" => "incoming_and_closed",
          "statements" => [{ "text" => "Der Eingang war ruhig.", "report_ids" => [light_report.id] }] }
      ]
      expect(report.generated_at).to be_present
    end

    it "only shows the AI reports of the profile's categories" do
      profile.update!(category_ids: [waste.id])
      chat = stub_llm_content(
        "sections" => [{ "building_block" => "incoming_and_closed",
                         "statements" => [{ "text" => "Aussage", "report_ids" => [light_report.id, waste_report.id] }] }]
      )

      described_class.call(report)

      expect(chat).to have_received(:ask) do |prompt|
        expect(prompt).to include("Sperrmüll am Weg")
        expect(prompt).not_to include("Laterne defekt")
      end
      expect(report.reload.sections.first["statements"].first["report_ids"]).to eq [waste_report.id]
    end

    it "passes the profile's instructions to the AI" do
      profile.update!(instructions: "Straßenbeleuchtung nicht berücksichtigen")
      chat = stub_llm_content("sections" => [])

      described_class.call(report)

      expect(chat).to have_received(:ask).with(including("Straßenbeleuchtung nicht berücksichtigen"))
    end

    it "books the AI usage under its own feature" do
      stub_llm_content("sections" => [])

      described_class.call(report)

      expect(Ai::RubyLlmFactory).to have_received(:chat_with_json_output)
        .with(anything, hash_including(feature: "deficiency_reports.management_report"))
      expect(AiUsageRecord::FEATURES).to include("deficiency_reports.management_report")
    end
  end

  describe "a failed run" do
    it "marks the report as failed when AI is not available" do
      allow(Ai::Settings).to receive(:ai_available?).and_return(false)

      expect { described_class.call(report) }.not_to raise_error

      expect(report.reload).to be_failed
      expect(report.error_message).to be_present
      expect(report.sections).to eq []
    end

    it "marks the report as failed when the provider is down" do
      allow(Ai::RubyLlmFactory).to receive(:chat_with_json_output).and_raise(StandardError, "provider down")

      described_class.call(report)

      expect(report.reload).to be_failed
      expect(report.error_message).to include("provider down")
    end
  end
end
