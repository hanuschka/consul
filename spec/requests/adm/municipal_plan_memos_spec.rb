require "rails_helper"

describe "Interne Notizen on a Vorhaben in /adm", type: :request do
  let(:admin) { create(:administrator).user }
  let(:officer) { create(:municipal_plan_officer) }
  let(:plan) { create(:municipal_plan, :published, responsible: officer) }

  before do
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
    allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)
    Setting["municipal_plans.officers_see_all"] = false
  end

  def add_memo(memoable, text)
    post adm_municipal_plans_memos_path, as: :turbo_stream, params: {
      memo: { text: text, memoable_id: memoable.id, memoable_type: "MunicipalPlan" }
    }
  end

  it "lets an administrator add a note that shows on the detail page" do
    login_as(admin)

    add_memo(plan, "Abstimmung mit dem Bauamt steht aus")

    expect(plan.memos.pluck(:text)).to eq(["Abstimmung mit dem Bauamt steht aus"])

    get adm_municipal_plans_municipal_plan_path(plan)

    expect(response.body).to include("Abstimmung mit dem Bauamt steht aus")
  end

  it "keeps a note written on a working copy with the released Vorhaben" do
    copy = MunicipalPlans::WorkingCopyService.call(plan)
    login_as(admin)

    add_memo(copy, "Gilt auch nach der Freigabe")

    expect(copy.memos).to be_empty
    expect(plan.memos.pluck(:text)).to eq(["Gilt auch nach der Freigabe"])
  end

  it "lets the responsible officer add a note" do
    login_as(officer.user)

    add_memo(plan, "Termin mit dem Planungsbüro vereinbart")

    expect(plan.memos.count).to eq(1)
  end

  it "keeps officers away from Vorhaben they may not see" do
    login_as(create(:municipal_plan_officer).user)

    add_memo(plan, "Darf nicht gespeichert werden")

    expect(plan.memos).to be_empty
  end

  it "lets the author delete their note" do
    memo = plan.memos.create!(user: admin, text: "Veraltet")
    login_as(admin)

    delete adm_municipal_plans_memo_path(memo), as: :turbo_stream

    expect(plan.memos.reload).to be_empty
  end

  it "notifies the responsible officer on Benachrichtigen" do
    memo = plan.memos.create!(user: admin, text: "Bitte bis Freitag prüfen")
    login_as(admin)

    expect { post send_notification_adm_municipal_plans_memo_path(memo), as: :turbo_stream }
      .to have_enqueued_mail(NotificationServiceMailer, :memo).with(memo.id, officer.user.id, anything)

    expect(memo.reload.last_notification_sent_at).to be_present
  end
end
