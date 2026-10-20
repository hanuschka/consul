require "rails_helper"

describe "Notifying the responsible officers about new comments on a deficiency report" do
  let(:admin) { create(:administrator).user }
  let(:report) { create(:deficiency_report) }
  let(:group) { create(:deficiency_report_officer_group, default_email: "team@example.org") }
  let(:group_officers) do
    create_list(:deficiency_report_officer, 2).each do |officer|
      create(:deficiency_report_officer_group_assignment, officer: officer, officer_group: group)
    end
  end

  before do
    set_setting("feature.deficiency_reports", true)
    create(:comment, commentable: report)
    sign_in(admin)
    ActionMailer::Base.deliveries.clear
  end

  def switch_on
    patch notify_officer_about_new_comments_deficiency_report_path(report),
          params: { deficiency_report: { notify_officer_about_new_comments: "1" }}, xhr: true
  end

  def recipients
    ActionMailer::Base.deliveries.flat_map(&:to)
  end

  it "mails the responsible officer" do
    officer = create(:deficiency_report_officer)
    report.update!(responsible: officer)

    switch_on

    expect(response).to have_http_status(:ok)
    expect(recipients).to eq([officer.email])
    expect(report.reload.notify_officer_about_new_comments).to be true
  end

  it "mails the address and every officer of a responsible group" do
    officer_emails = group_officers.map(&:email)
    report.update!(responsible: group)

    switch_on

    expect(recipients).to match_array(["team@example.org"] + officer_emails)
  end

  it "mails only the group address when groups are used for assignment only" do
    set_setting("deficiency_reports.officer_groups_only_for_assignment", true)
    group_officers
    report.update!(responsible: group)

    switch_on

    expect(recipients).to eq(["team@example.org"])
  end

  it "leaves the setting alone when nobody is responsible" do
    switch_on

    expect(response).to be_successful
    expect(recipients).to be_empty
    expect(report.reload.notify_officer_about_new_comments).to be false
  end
end
