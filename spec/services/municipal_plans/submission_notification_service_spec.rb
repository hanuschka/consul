require "rails_helper"

describe MunicipalPlans::SubmissionNotificationService do
  let(:officer) { create(:municipal_plan_officer) }
  let(:plan) { create(:municipal_plan, responsible: officer) }
  let(:delivery) { double(deliver_later: true) }

  it "mails every administrator" do
    administrators = create_list(:administrator, 2)

    administrators.each do |administrator|
      expect(MunicipalPlanMailer).to receive(:submitted_for_release)
        .with(plan, administrator).and_return(delivery)
    end

    MunicipalPlans::SubmissionNotificationService.call(plan)
  end

  it "skips an administrator without an address" do
    create(:administrator).user.update_columns(email: nil)

    expect(MunicipalPlanMailer).not_to receive(:submitted_for_release)

    MunicipalPlans::SubmissionNotificationService.call(plan)
  end

  it "manages without any administrator" do
    expect { MunicipalPlans::SubmissionNotificationService.call(plan) }.not_to raise_error
  end
end
