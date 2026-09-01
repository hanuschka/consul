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

      expect(registered).to match_array %w[officer_name overdue_count fresh_count]
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
end
