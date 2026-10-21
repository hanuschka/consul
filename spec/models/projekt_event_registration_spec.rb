require "rails_helper"

describe ProjektEventRegistration do
  def register(event, email)
    registration = event.projekt_event_registrations.new(
      first_name: "Anna", last_name: "Beispiel", email: email
    )
    registration.skip_email_confirmation!
    registration.save!
    registration
  end

  context "registration without an attendee limit" do
    let(:event) { create(:projekt_event, registration_enabled: true, max_attendees: nil) }

    it "confirms every registrant and never uses the waitlist" do
      30.times { |i| register(event, "person#{i}@example.org") }

      expect(event.projekt_event_registrations.confirmed.count).to eq 30
      expect(event.projekt_event_registrations.waitlisted).to be_empty
    end

    it "confirms a registrant after the e-mail confirmation" do
      registration = event.projekt_event_registrations.create!(
        first_name: "Anna", last_name: "Beispiel", email: "anna@example.org"
      )
      expect(registration).to be_pending_confirmation

      registration.confirm_email!

      expect(registration.reload.status).to eq "confirmed"
    end
  end

  context "registration with an attendee limit" do
    let(:event) { create(:projekt_event, registration_enabled: true, max_attendees: 2) }

    it "puts registrants beyond the limit on the waitlist" do
      first = register(event, "first@example.org")
      second = register(event, "second@example.org")
      third = register(event, "third@example.org")

      expect([first, second].map(&:status)).to eq %w[confirmed confirmed]
      expect(third.status).to eq "waitlisted"
    end

    it "moves the next waitlisted registrant up when a confirmed one leaves" do
      first = register(event, "first@example.org")
      register(event, "second@example.org")
      third = register(event, "third@example.org")

      first.destroy!

      expect(third.reload.status).to eq "confirmed"
    end
  end
end
