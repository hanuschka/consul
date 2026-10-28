require "rails_helper"

describe DeficiencyReportMailer do
  let(:report) { create(:deficiency_report, title: "Schlagloch in der Hauptstraße") }
  let(:recipient) { create(:user, email: "sachbearbeiter@example.org", username: "Sachbearbeiter") }

  describe "#notify_shared_report" do
    let(:sharer) { create(:user, username: "Kollegin") }
    let(:mail) { DeficiencyReportMailer.notify_shared_report(report, recipient, sharer) }

    it "goes to the recipient" do
      expect(mail.to).to eq([recipient.email])
    end

    it "names the report in the subject" do
      expect(mail.subject).to include(report.id.to_s)
      expect(mail.subject).to include(report.title)
    end

    it "links to the report in the backend" do
      expect(mail.body.encoded).to include(
        Rails.application.routes.url_helpers.adm_deficiency_reports_deficiency_report_path(report)
      )
    end

    # The whole point of the mail: a recipient who does not want the follow-up notifications can drop
    # them without hunting for the bell.
    it "carries the one-click opt-out link" do
      expect(mail.body.encoded).to include(
        Rails.application.routes.url_helpers.unwatch_adm_deficiency_reports_deficiency_report_path(report)
      )
    end

    it "sends nothing when the report is missing" do
      mail = DeficiencyReportMailer.notify_shared_report(nil, recipient, sharer)

      expect { mail.deliver_now }.not_to change(ActionMailer::Base.deliveries, :count)
    end

    it "sends nothing when the recipient is missing" do
      mail = DeficiencyReportMailer.notify_shared_report(report, nil, sharer)

      expect { mail.deliver_now }.not_to change(ActionMailer::Base.deliveries, :count)
    end

    it "sends nothing when the recipient has no email address" do
      recipient.update_column(:email, nil)

      expect { DeficiencyReportMailer.notify_shared_report(report, recipient.reload, sharer).deliver_now }
        .not_to change(ActionMailer::Base.deliveries, :count)
    end

    it "survives a sharer who is no longer around" do
      expect { DeficiencyReportMailer.notify_shared_report(report, recipient, nil).deliver_now }
        .to change(ActionMailer::Base.deliveries, :count).by(1)
    end
  end

  describe "#notify_watcher_about_change" do
    let(:mail) { DeficiencyReportMailer.notify_watcher_about_change(report, recipient) }

    it "goes to the watcher" do
      expect(mail.to).to eq([recipient.email])
    end

    it "names the report in the subject" do
      expect(mail.subject).to include(report.id.to_s)
      expect(mail.subject).to include(report.title)
    end

    it "links to the report and offers the opt-out" do
      helpers = Rails.application.routes.url_helpers

      body = mail.body.encoded

      expect(body).to include(helpers.adm_deficiency_reports_deficiency_report_path(report))
      expect(body).to include(helpers.unwatch_adm_deficiency_reports_deficiency_report_path(report))
    end

    it "sends nothing when the report is missing" do
      mail = DeficiencyReportMailer.notify_watcher_about_change(nil, recipient)

      expect { mail.deliver_now }.not_to change(ActionMailer::Base.deliveries, :count)
    end

    it "sends nothing when the watcher is missing" do
      mail = DeficiencyReportMailer.notify_watcher_about_change(report, nil)

      expect { mail.deliver_now }.not_to change(ActionMailer::Base.deliveries, :count)
    end
  end

  describe "#notify_author_about_official_answer" do
    let(:mail) { DeficiencyReportMailer.notify_author_about_official_answer(report) }

    before { report.update!(official_answer: "<p>Die Stelle wird am Montag ausgebessert.</p>") }

    it "goes to the reporter" do
      expect(mail.to).to eq([report.author.email])
    end

    it "shows the official answer and links to the report" do
      expect(mail.body.encoded).to include("Die Stelle wird am Montag ausgebessert.")
      expect(mail.body.encoded).to include(
        Rails.application.routes.url_helpers.deficiency_report_path(report)
      )
    end
  end
end
