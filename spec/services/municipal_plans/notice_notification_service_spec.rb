require "rails_helper"

describe MunicipalPlans::NoticeNotificationService do
  let(:officer) { create(:municipal_plan_officer) }
  let(:plan) { create(:municipal_plan, :published, responsible: officer) }
  let(:notice) { plan.notices.create!(email: "buerger@example.org", body: "Eine Frage") }
  let(:delivery) { double(deliver_later: true) }

  it "mails the Sachbearbeitung the Vorhaben is assigned to" do
    expect(MunicipalPlanMailer).to receive(:notice_submitted)
      .with(notice, officer.user.email).and_return(delivery)

    MunicipalPlans::NoticeNotificationService.call(notice)
  end

  it "mails every member of a Bearbeitergruppe" do
    group = create(:municipal_plan_officer_group)
    members = create_list(:municipal_plan_officer, 2)
    members.each do |member|
      create(:municipal_plan_officer_group_assignment, officer: member, officer_group: group)
    end
    plan.update!(responsible: group)

    members.each do |member|
      expect(MunicipalPlanMailer).to receive(:notice_submitted)
        .with(notice, member.user.email).and_return(delivery)
    end

    MunicipalPlans::NoticeNotificationService.call(notice)
  end

  it "mails the Systempostfach in addition" do
    plan.update!(system_mailbox_email: "postfach@jena.example")

    expect(MunicipalPlanMailer).to receive(:notice_submitted)
      .with(notice, officer.user.email).and_return(delivery)
    expect(MunicipalPlanMailer).to receive(:notice_submitted)
      .with(notice, "postfach@jena.example").and_return(delivery)

    MunicipalPlans::NoticeNotificationService.call(notice)
  end

  it "sends one mail when the Systempostfach is the Sachbearbeitung's own address" do
    plan.update!(system_mailbox_email: officer.user.email)

    expect(MunicipalPlanMailer).to receive(:notice_submitted).once.and_return(delivery)

    MunicipalPlans::NoticeNotificationService.call(notice)
  end

  it "manages a Vorhaben without a Zuständigkeit" do
    plan.update_columns(responsible_type: nil, responsible_id: nil)

    expect(MunicipalPlanMailer).not_to receive(:notice_submitted)

    MunicipalPlans::NoticeNotificationService.call(notice.reload)
  end
end
