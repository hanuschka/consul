require "rails_helper"

describe NotificationServiceMailer do
  describe "#overdue_deficiency_reports_overview" do
    let(:officer) { create(:deficiency_report_officer, manage_all: true) }
    let(:responsible_officer) { create(:deficiency_report_officer) }
    let(:fresh_report) do
      create(:deficiency_report, title: "Broken swing", responsible: responsible_officer)
    end
    let(:carried_over_report) do
      create(:deficiency_report, title: "Blocked drain", responsible: responsible_officer)
    end

    def overview(overdue_reports, fresh_reports = [])
      described_class.overdue_deficiency_reports_overview(officer.id, overdue_reports.map(&:id),
                                                          fresh_reports.map(&:id))
    end

    def body_of(mail)
      mail.body.decoded
    end

    def copy(key, **interpolations)
      I18n.t("custom.notification_service_mailers.overdue_deficiency_reports_overview.#{key}",
             **interpolations)
    end

    # The template escapes the copy it prints, so comparing against the raw translation would miss
    # on any key that contains quotes.
    def escaped(text)
      CGI.escapeHTML(text)
    end

    before { ActionMailer::Base.deliveries.clear }

    it "goes to the officer who manages all reports" do
      mail = overview([fresh_report], [fresh_report])

      expect(mail.to).to eq [officer.user.email]
      expect(mail.subject).to eq copy(:subject)
    end

    it "sends nothing when the officer's user account is gone" do
      officer.update!(user: nil)
      mail = overview([fresh_report], [fresh_report])

      expect(mail.message).to be_a ActionMailer::Base::NullMail
      expect { mail.deliver_now }.not_to change { ActionMailer::Base.deliveries.count }
    end

    it "links to every overdue report" do
      body = body_of(overview([fresh_report, carried_over_report], [fresh_report]))

      expect(body).to include "Broken swing"
      expect(body).to include "/adm/deficiency_reports/#{fresh_report.id}"
      expect(body).to include "Blocked drain"
      expect(body).to include "/adm/deficiency_reports/#{carried_over_report.id}"
    end

    it "marks only today's arrivals as new" do
      body = body_of(overview([fresh_report, carried_over_report], [fresh_report]))

      expect(body.scan("<strong>#{copy(:fresh_badge)}</strong>").size).to eq 1
      expect(body.index(escaped("Broken swing"))).to be < body.index(escaped("Blocked drain"))
    end

    it "lists today's arrivals before the rest of the backlog" do
      body = body_of(overview([carried_over_report, fresh_report], [fresh_report]))

      expect(body.index(escaped("Broken swing"))).to be < body.index(escaped("Blocked drain"))
    end

    it "explains the badge when something is new" do
      body = body_of(overview([fresh_report], [fresh_report]))

      expect(body).to include escaped(copy(:fresh_hint, label: copy(:fresh_badge)))
    end

    it "leaves the badge unexplained when nothing is new" do
      body = body_of(overview([carried_over_report], []))

      expect(body).not_to include escaped(copy(:fresh_hint, label: copy(:fresh_badge)))
      expect(body).not_to include "<strong>#{copy(:fresh_badge)}</strong>"
    end

    it "addresses a single overdue report in the singular" do
      body = body_of(overview([fresh_report], [fresh_report]))

      expect(body).to include escaped(copy(:p1_s))
      expect(body).not_to include escaped(copy(:p1_p))
    end

    it "addresses several overdue reports in the plural" do
      body = body_of(overview([fresh_report, carried_over_report], [fresh_report]))

      expect(body).to include escaped(copy(:p1_p))
      expect(body).not_to include escaped(copy(:p1_s))
    end

    it "names who is responsible for each report" do
      group = create(:deficiency_report_officer_group, name: "Green space team")
      group_report = create(:deficiency_report, title: "Overgrown hedge", responsible: group)

      body = body_of(overview([fresh_report, group_report], []))

      expect(body).to include responsible_officer.name
      expect(body).to include "Green space team"
    end

    it "says so when the responsible party no longer exists" do
      fresh_report.update_columns(responsible_type: "DeficiencyReport::Officer", responsible_id: 0)

      body = body_of(overview([fresh_report], []))

      expect(body).to include escaped(copy(:no_responsible))
    end

    context "with a customized email template" do
      before do
        SiteCustomization::EmailTemplate.create!(
          mailer_class: "NotificationServiceMailer",
          mailer_action: "overdue_deficiency_reports_overview",
          locale: "en",
          subject: "{{ overdue_count }} reports are overdue",
          body: "Hello {{ officer_name }}, {{ fresh_count }} of {{ overdue_count }} reports are new."
        )
      end

      it "renders the template with every variable the editor offers" do
        mail = overview([fresh_report, carried_over_report], [fresh_report])

        expect(mail.subject).to eq "2 reports are overdue"
        expect(body_of(mail)).to include "Hello #{officer.name}, 1 of 2 reports are new."
      end
    end

    it "is offered for customization in the deficiency report section" do
      expect(SiteCustomization::EmailTemplate::DEFICIENCY_REPORT_EMAIL_TEMPLATES)
        .to include ["NotificationServiceMailer", "overdue_deficiency_reports_overview"]
    end

    it "declares the variables the mailer passes" do
      registered = SiteCustomization::EmailTemplate::EMAIL_TEMPLATES
                     .dig("NotificationServiceMailer#overdue_deficiency_reports_overview", :variables)

      expect(registered).to match_array %w[recipient_greeting overdue_count fresh_count]
    end

    it "has its copy translated in every locale the email is sent in" do
      keys = %i[subject hi p1_s p1_p fresh_badge fresh_hint no_responsible]

      %i[en de].each do |locale|
        keys.each do |key|
          expect(copy(key, locale: locale, label: copy(:fresh_badge, locale: locale), raise: true))
            .to be_present
        end
      end
    end
  end

  describe "#memo" do
    include ActiveJob::TestHelper

    let(:report) { create(:deficiency_report, title: "Broken swing") }
    let(:memo) { Memo.create!(memoable: report, user: create(:user), text: "Checked on site") }

    let!(:administrator) { create(:administrator) }

    before do
      ActionMailer::Base.deliveries.clear
    end

    def notify_about(memoable)
      memo = Memo.create!(memoable: memoable, user: create(:user), text: "Bitte prüfen")
      perform_enqueued_jobs { NotificationServices::MemoNotifier.new(memo.id).call }
    end

    def body_for(user)
      ActionMailer::Base.deliveries.find { |mail| mail.to.include?(user.email) }.body.decoded
    end

    it "links a deficiency report memo to the report in /adm" do
      perform_enqueued_jobs { NotificationServices::MemoNotifier.new(memo.id).call }
      body = ActionMailer::Base.deliveries.last.body.decoded

      expect(body).to include "/adm/deficiency_reports/#{report.id}"
      expect(body).not_to include "deficiency_report_management"
    end

    it "links a proposal memo to the proposal in /adm for administrators and projekt managers" do
      proposal = create(:proposal)
      projekt_manager = create(:projekt_manager)
      create(:projekt_manager_assignment, :get_notifications,
             projekt: proposal.projekt, projekt_manager: projekt_manager)

      notify_about(proposal)

      [administrator.user, projekt_manager.user].each do |recipient|
        body = body_for(recipient)

        expect(body).to include "/adm/projekts/phases/#{proposal.projekt_phase.id}/proposals/#{proposal.id}"
        expect(body).not_to include "/admin/"
        expect(body).not_to include "/projekt_management/"
      end
    end

    it "links a budget investment memo to the investment in /adm" do
      investment = create(:budget_investment)

      notify_about(investment)

      expect(body_for(administrator.user))
        .to include "/adm/projekts/phases/#{investment.projekt_phase.id}/budget_investments/#{investment.id}"
    end

    it "links an idea memo to the idea in /adm" do
      idea = create(:idea)

      notify_about(idea)

      expect(body_for(administrator.user)).to include "/adm/ideas/#{idea.id}"
    end
  end

  describe "#new_manual_verification_request" do
    it "links to the user list in /adm" do
      admin = create(:administrator).user
      body = described_class.new_manual_verification_request(admin.id, create(:user).id).body.decoded

      expect(body).to include "/adm/users"
      expect(body).not_to include "/admin/users"
    end
  end

  describe "#new_contribution_comment" do
    let(:admin) { create(:administrator).user }
    let(:comment) { create(:comment, commentable: create(:proposal), body: "Tolle Idee") }

    it "uses the default text" do
      mail = described_class.new_contribution_comment(admin.id, comment.id)

      expect(mail.subject).to eq I18n.t("custom.notification_service_mailers.new_contribution_comment.subject")
      expect(mail.body.encoded).to include("Tolle Idee")
    end

    it "uses the global template" do
      SiteCustomization::EmailTemplate.create!(
        mailer_class: "NotificationServiceMailer",
        mailer_action: "new_contribution_comment",
        locale: admin.locale,
        subject: "Neuer Kommentar",
        body: "<p>Kommentar: {{ comment_body }}</p>"
      )

      mail = described_class.new_contribution_comment(admin.id, comment.id)

      expect(mail.subject).to eq "Neuer Kommentar"
      expect(mail.body.encoded).to include("Kommentar: Tolle Idee")
    end
  end
end
