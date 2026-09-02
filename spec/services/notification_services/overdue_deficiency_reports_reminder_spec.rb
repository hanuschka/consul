require "rails_helper"

describe NotificationServices::OverdueDeficiencyReportsReminder do
  let(:status) { create(:deficiency_report_status, reminder_delay: 7) }
  let(:officer) { create(:deficiency_report_officer) }
  let(:other_officer) { create(:deficiency_report_officer) }
  let(:oversight_officer) { create(:deficiency_report_officer, manage_all: true) }

  # CURRENT_DATE is evaluated by the database session, which can sit on a different calendar day
  # than the application clock. Anchoring every timestamp to the database's own date keeps the two
  # SQL windows exact no matter what time the suite runs at.
  let(:db_today) { DeficiencyReport.connection.select_value("SELECT CURRENT_DATE").to_date }
  let(:dispatched) { { personal: [], overview: [] } }

  def stuck_since(days)
    (db_today - days).midday
  end

  def create_report(responsible:, days_stuck: 7, report_status: status, **attributes)
    create(:deficiency_report,
           status: report_status,
           responsible: responsible,
           assigned_at: stuck_since(days_stuck),
           status_changed_at: stuck_since(days_stuck),
           **attributes)
  end

  # Recording the dispatch instead of rendering it keeps these examples about *who* is notified with
  # *which* reports; the rendering is covered in the mailer spec. The plain double also fails the
  # example if the service ever stops going through deliver_later.
  def record_dispatch
    allow(NotificationServiceMailer).to receive(:overdue_deficiency_reports) do |officer_id, report_ids|
      dispatched[:personal] << { officer_id: officer_id, report_ids: report_ids }
      double("MessageDelivery", deliver_later: true)
    end

    allow(NotificationServiceMailer)
      .to receive(:overdue_deficiency_reports_overview) do |officer_id, report_ids, fresh_ids|
      dispatched[:overview] << { officer_id: officer_id, report_ids: report_ids, fresh_ids: fresh_ids }
      double("MessageDelivery", deliver_later: true)
    end
  end

  def personal_recipient_ids
    dispatched[:personal].map { |mail| mail[:officer_id] }
  end

  def overview_recipient_ids
    dispatched[:overview].map { |mail| mail[:officer_id] }
  end

  def personal_digest_for(digest_officer)
    dispatched[:personal].find { |mail| mail[:officer_id] == digest_officer.id }
  end

  def overview_for(overview_officer)
    dispatched[:overview].find { |mail| mail[:officer_id] == overview_officer.id }
  end

  describe "recipients" do
    before { record_dispatch }

    it "notifies the responsible officer about a report that crosses its reminder delay today" do
      report = create_report(responsible: officer)

      described_class.new.call

      expect(personal_recipient_ids).to eq [officer.id]
      expect(personal_digest_for(officer)[:report_ids]).to eq [report.id]
    end

    it "sends the overview to every officer who manages all reports, even without reports of their own" do
      oversight_officer
      second_oversight_officer = create(:deficiency_report_officer, manage_all: true)
      report = create_report(responsible: officer)

      described_class.new.call

      expect(overview_recipient_ids).to match_array [oversight_officer.id, second_oversight_officer.id]
      expect(overview_for(oversight_officer)[:report_ids]).to eq [report.id]
      expect(overview_for(second_oversight_officer)[:report_ids]).to eq [report.id]
    end

    it "sends no overview when nobody manages all reports" do
      create_report(responsible: officer)

      described_class.new.call

      expect(overview_recipient_ids).to be_empty
      expect(personal_recipient_ids).to eq [officer.id]
    end

    it "sends only the overview to an officer who manages all reports and is responsible as well" do
      report = create_report(responsible: oversight_officer)

      described_class.new.call

      expect(personal_recipient_ids).to be_empty
      expect(overview_recipient_ids).to eq [oversight_officer.id]
      expect(overview_for(oversight_officer)[:report_ids]).to eq [report.id]
    end

    it "notifies every officer of the responsible officer group" do
      group = create(:deficiency_report_officer_group, officers: [officer, other_officer])
      report = create_report(responsible: group)

      described_class.new.call

      expect(personal_recipient_ids).to match_array [officer.id, other_officer.id]
      expect(personal_digest_for(officer)[:report_ids]).to eq [report.id]
      expect(personal_digest_for(other_officer)[:report_ids]).to eq [report.id]
    end

    it "keeps an officer who manages all reports out of their group's personal digest" do
      group = create(:deficiency_report_officer_group, officers: [officer, oversight_officer])
      create_report(responsible: group)

      described_class.new.call

      expect(personal_recipient_ids).to eq [officer.id]
      expect(overview_recipient_ids).to eq [oversight_officer.id]
    end

    it "notifies nobody personally when the responsible officer group has no officers" do
      report = create_report(responsible: create(:deficiency_report_officer_group))
      oversight_officer

      described_class.new.call

      expect(personal_recipient_ids).to be_empty
      expect(overview_for(oversight_officer)[:report_ids]).to eq [report.id]
    end

    it "includes the reports an officer is responsible for both in person and through a group" do
      group = create(:deficiency_report_officer_group, officers: [officer])
      own_report = create_report(responsible: officer)
      group_report = create_report(responsible: group)

      described_class.new.call

      expect(personal_digest_for(officer)[:report_ids]).to match_array [own_report.id, group_report.id]
    end

    it "does not tell an officer about a report somebody else is responsible for" do
      own_report = create_report(responsible: officer)
      create_report(responsible: other_officer)

      described_class.new.call

      expect(personal_digest_for(officer)[:report_ids]).to eq [own_report.id]
    end
  end

  describe "the standing backlog versus today's arrivals" do
    before do
      record_dispatch
      oversight_officer
    end

    it "reports today's arrivals separately from the rest of the backlog" do
      fresh_report = create_report(responsible: officer, days_stuck: 7)
      carried_over_report = create_report(responsible: officer, days_stuck: 30)

      described_class.new.call

      overview = overview_for(oversight_officer)
      expect(overview[:report_ids]).to match_array [fresh_report.id, carried_over_report.id]
      expect(overview[:fresh_ids]).to eq [fresh_report.id]
    end

    it "sends the overview on a day when nothing new becomes overdue" do
      carried_over_report = create_report(responsible: officer, days_stuck: 30)

      described_class.new.call

      overview = overview_for(oversight_officer)
      expect(overview[:report_ids]).to eq [carried_over_report.id]
      expect(overview[:fresh_ids]).to be_empty
    end

    it "leaves the personal digest quiet on a day when nothing new becomes overdue" do
      create_report(responsible: officer, days_stuck: 30)

      described_class.new.call

      expect(personal_recipient_ids).to be_empty
    end

    it "sends nothing at all once the backlog is empty" do
      create_report(responsible: officer, days_stuck: 3)
      oversight_officer

      described_class.new.call

      expect(personal_recipient_ids).to be_empty
      expect(overview_recipient_ids).to be_empty
    end

    it "treats a report that is exactly at its reminder delay as a new arrival" do
      report = create_report(responsible: officer, days_stuck: 7)

      described_class.new.call

      expect(personal_digest_for(officer)[:report_ids]).to eq [report.id]
      expect(overview_for(oversight_officer)[:fresh_ids]).to eq [report.id]
    end

    it "ignores a report that has not reached its reminder delay yet" do
      create_report(responsible: officer, days_stuck: 6)
      oversight_officer

      described_class.new.call

      expect(personal_recipient_ids).to be_empty
      expect(overview_recipient_ids).to be_empty
    end

    it "treats a report under a status without any delay as overdue on the same day" do
      immediate_status = create(:deficiency_report_status, reminder_delay: 0)
      report = create_report(responsible: officer, days_stuck: 0, report_status: immediate_status)

      described_class.new.call

      expect(personal_digest_for(officer)[:report_ids]).to eq [report.id]
      expect(overview_for(oversight_officer)[:fresh_ids]).to eq [report.id]
    end
  end

  describe "the date the delay is counted from" do
    before do
      record_dispatch
      oversight_officer
    end

    it "counts from the status change when that is the more recent of the two" do
      report = create_report(responsible: officer, assigned_at: stuck_since(30),
                             status_changed_at: stuck_since(7))

      described_class.new.call

      expect(overview_for(oversight_officer)[:fresh_ids]).to eq [report.id]
    end

    it "counts from the assignment when that is the more recent of the two" do
      report = create_report(responsible: officer, assigned_at: stuck_since(7),
                             status_changed_at: stuck_since(30))

      described_class.new.call

      expect(overview_for(oversight_officer)[:fresh_ids]).to eq [report.id]
    end
  end

  describe "which reports count as overdue" do
    before do
      record_dispatch
      oversight_officer
    end

    it "ignores reports nobody is responsible for" do
      create(:deficiency_report, status: status, responsible: nil, assigned_at: nil,
             status_changed_at: stuck_since(7))

      described_class.new.call

      expect(personal_recipient_ids).to be_empty
      expect(overview_recipient_ids).to be_empty
    end

    it "falls back to the status change when the assignment date was never recorded" do
      report = create_report(responsible: officer, assigned_at: nil)

      described_class.new.call

      expect(personal_digest_for(officer)[:report_ids]).to eq [report.id]
      expect(overview_for(oversight_officer)[:fresh_ids]).to eq [report.id]
    end

    it "ignores reports whose status closes them" do
      closed_status = create(:deficiency_report_status, reminder_delay: 7, archive_reports: true)
      create_report(responsible: officer, report_status: closed_status)

      described_class.new.call

      expect(personal_recipient_ids).to be_empty
      expect(overview_recipient_ids).to be_empty
    end

    it "ignores reports whose status has no reminder delay" do
      status_without_delay = create(:deficiency_report_status, reminder_delay: nil)
      create_report(responsible: officer, report_status: status_without_delay)

      described_class.new.call

      expect(personal_recipient_ids).to be_empty
      expect(overview_recipient_ids).to be_empty
    end

    it "ignores reports whose status change was never recorded" do
      create_report(responsible: officer, status_changed_at: nil)

      described_class.new.call

      expect(personal_recipient_ids).to be_empty
      expect(overview_recipient_ids).to be_empty
    end

    it "ignores reports that already carry an official answer" do
      create_report(responsible: officer, official_answer: "Already taken care of")

      described_class.new.call

      expect(personal_recipient_ids).to be_empty
      expect(overview_recipient_ids).to be_empty
    end

    it "counts a report with a blank official answer as unanswered" do
      report = create_report(responsible: officer, official_answer: "")

      described_class.new.call

      expect(personal_digest_for(officer)[:report_ids]).to eq [report.id]
    end
  end

  describe "delivery" do
    before { ActionMailer::Base.deliveries.clear }

    it "emails the responsible officer and the officer who manages all reports" do
      create_report(responsible: officer, days_stuck: 7)
      create_report(responsible: other_officer, days_stuck: 30)
      oversight_officer

      described_class.new.call

      expect(ActionMailer::Base.deliveries.map(&:to).flatten)
        .to match_array [officer.user.email, oversight_officer.user.email]
    end

    it "sends no email when nothing is overdue" do
      create_report(responsible: officer, days_stuck: 3)
      oversight_officer

      described_class.new.call

      expect(ActionMailer::Base.deliveries).to be_empty
    end
  end
end
