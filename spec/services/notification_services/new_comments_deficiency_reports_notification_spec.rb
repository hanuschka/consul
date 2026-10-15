require "rails_helper"

describe NotificationServices::NewCommentsDeficiencyReportsNotification do
  before { ActionMailer::Base.deliveries.clear }

  it "reminds the responsible officer about comments since the last notification" do
    officer = create(:deficiency_report_officer)
    report = create(:deficiency_report, responsible: officer, notify_officer_about_new_comments: true,
                                        notified_officer_about_new_comments_datetime: 1.day.ago)
    create(:comment, commentable: report)

    NotificationServices::NewCommentsDeficiencyReportsNotification.call

    expect(ActionMailer::Base.deliveries.flat_map(&:to)).to eq([officer.email])
  end
end
