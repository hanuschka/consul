require "rails_helper"

describe "Scheduled management reports" do
  include ActiveJob::TestHelper

  def stub_llm_content(content)
    chat = double("chat")
    allow(chat).to receive(:ask).and_return(RubyLLM::Message.new(role: :assistant, content: content.to_json))
    allow(Ai::RubyLlmFactory).to receive(:chat_with_json_output)
      .and_return(double("chat_builder", with_instructions: chat))
  end

  let(:friday_15) { Time.zone.local(2026, 10, 23, 15, 0, 20) }
  let(:officer) { create(:deficiency_report_officer) }
  let!(:profile) do
    create(:deficiency_report_report_profile,
           name: "Bürgermeister", frequency: "weekly", weekday: 5, hour: 15,
           building_blocks: %w[incoming_and_closed],
           recipient_user_ids: [officer.user_id], recipient_emails: ["buergermeister@example.org"])
  end

  before do
    create(:deficiency_report_status)
    allow(DtApi::Client).to receive(:new).and_raise(StandardError, "no DT API in test")
    allow(Ai::Settings).to receive(:ai_available?).and_return(true)
    stub_llm_content("sections" => [{ "building_block" => "incoming_and_closed",
                                      "statements" => [{ "text" => "Ruhige Woche.", "report_ids" => [] }] }])
    ActionMailer::Base.deliveries.clear
  end

  def run_schedule_at(time)
    travel_to(time) { perform_enqueued_jobs { DeficiencyReports::ManagementReports::ScheduleDue.call } }
  end

  it "sends one e-mail with the PDF to each recipient at the scheduled time" do
    run_schedule_at(friday_15)

    mails = ActionMailer::Base.deliveries
    expect(mails.flat_map(&:to)).to match_array [officer.user.email, "buergermeister@example.org"]
    mails.each do |mail|
      expect(mail.attachments.map(&:mime_type)).to eq ["application/pdf"]
      expect(mail.text_part.decoded).to include("Bürgermeister")
    end

    report = profile.management_reports.last
    expect(report).to be_scheduled
    expect(report.sent_at).to be_present
  end

  it "links account recipients to the report in the administration, but not plain e-mail recipients" do
    run_schedule_at(friday_15)

    report_url_path = "/adm/deficiency_reports/management_reports/#{profile.management_reports.last.id}"
    account_mail = ActionMailer::Base.deliveries.find { |mail| mail.to == [officer.user.email] }
    plain_mail = ActionMailer::Base.deliveries.find { |mail| mail.to == ["buergermeister@example.org"] }

    expect(account_mail.html_part.decoded).to include(report_url_path)
    expect(account_mail.text_part.decoded).to include(report_url_path)
    expect(plain_mail.html_part.decoded).not_to include(report_url_path)
    expect(plain_mail.text_part.decoded).not_to include(report_url_path)
  end

  it "does nothing at another hour or on another day" do
    run_schedule_at(friday_15.change(hour: 14))
    run_schedule_at(friday_15 - 1.day)

    expect(profile.management_reports).to be_empty
    expect(ActionMailer::Base.deliveries).to be_empty
  end

  it "runs a monthly profile on its day of the month" do
    profile.update!(frequency: "monthly", day_of_month: 23)

    run_schedule_at(friday_15)

    expect(profile.management_reports.count).to eq 1
  end

  it "sends nothing for a paused profile" do
    profile.update!(paused: true)

    run_schedule_at(friday_15)

    expect(profile.management_reports).to be_empty
    expect(ActionMailer::Base.deliveries).to be_empty
  end

  it "creates only one scheduled report when the task runs twice in the same hour" do
    run_schedule_at(friday_15)
    run_schedule_at(friday_15 + 20.minutes)

    expect(profile.management_reports.count).to eq 1
    expect(ActionMailer::Base.deliveries.size).to eq 2
  end

  it "creates a report on demand without sending it" do
    perform_enqueued_jobs do
      DeficiencyReport::ManagementReport.start_for(profile, trigger: :manual, deliver: false)
    end

    expect(profile.management_reports.last).to be_completed
    expect(profile.management_reports.last.sent_at).to be_nil
    expect(ActionMailer::Base.deliveries).to be_empty
  end

  it "marks the run as failed and sends nothing when AI is unavailable, and a retry sends the report" do
    allow(Ai::Settings).to receive(:ai_available?).and_return(false)
    run_schedule_at(friday_15)

    report = profile.management_reports.last
    expect(report).to be_failed
    expect(ActionMailer::Base.deliveries).to be_empty

    allow(Ai::Settings).to receive(:ai_available?).and_return(true)
    perform_enqueued_jobs { report.retry! }

    expect(report.reload).to be_completed
    expect(report.sent_at).to be_present
    expect(ActionMailer::Base.deliveries.size).to eq 2
  end
end
