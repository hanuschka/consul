require "rails_helper"

describe NotificationServices::NotAssignedDeficiencyReportsReminder do
  let!(:manager) { create(:user).tap { |user| DeficiencyReportManager.create!(user: user) } }
  let(:dispatched) { [] }

  def record_dispatch
    allow(NotificationServiceMailer).to receive(:not_assigned_deficiency_reports) do |user_id, report_ids|
      dispatched << { user_id: user_id, report_ids: report_ids }
      double("MessageDelivery", deliver_later: true)
    end
  end

  def unassigned_report(created:, assigned_at: nil)
    create(:deficiency_report).tap do |report|
      report.update_columns(created_at: created, assigned_at: assigned_at,
                            responsible_type: nil, responsible_id: nil)
    end
  end

  describe "which reports it reminds about" do
    before { record_dispatch }

    it "includes a report created 14 days ago that was never assigned" do
      report = unassigned_report(created: 14.days.ago)

      NotificationServices::NotAssignedDeficiencyReportsReminder.new.call

      expect(dispatched).to eq [{ user_id: manager.id, report_ids: [report.id] }]
    end

    it "includes a report whose assignee was removed 14 days ago" do
      report = unassigned_report(created: 30.days.ago, assigned_at: 14.days.ago)

      NotificationServices::NotAssignedDeficiencyReportsReminder.new.call

      expect(dispatched.first[:report_ids]).to eq [report.id]
    end

    it "leaves out younger reports and reports that have an assignee" do
      unassigned_report(created: 13.days.ago)
      create(:deficiency_report, responsible: create(:deficiency_report_officer))
        .update_columns(created_at: 14.days.ago)

      NotificationServices::NotAssignedDeficiencyReportsReminder.new.call

      expect(dispatched).to be_empty
    end
  end

  it "delivers the reminder to an Anliegen manager who is not an administrator" do
    report = unassigned_report(created: 14.days.ago)
    ActionMailer::Base.deliveries.clear

    NotificationServices::NotAssignedDeficiencyReportsReminder.new.call

    mail = ActionMailer::Base.deliveries.last
    expect(mail.to).to eq [manager.email]
    expect(mail.body.encoded).to include report.title
  end
end
