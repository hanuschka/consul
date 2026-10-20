require "rails_helper"

describe ProjektEvent do
  describe "registration without an attendee limit" do
    let(:event) { create(:projekt_event, registration_enabled: true, max_attendees: nil) }

    it "saves with registration on and no limit" do
      expect(event).to be_persisted
      expect(event).to be_registration_enabled
      expect(event.max_attendees).to be_nil
    end

    it "has no attendee limit and is never fully booked" do
      expect(event).not_to be_attendee_limit
      expect(event).not_to be_fully_booked
    end
  end

  describe "registration with an attendee limit" do
    let(:event) { create(:projekt_event, registration_enabled: true, max_attendees: 1) }

    it "is fully booked once the limit is reached" do
      expect(event).to be_attendee_limit
      expect(event).not_to be_fully_booked

      create_confirmed_registration(event)

      expect(event.spots_available).to eq 0
      expect(event).to be_fully_booked
    end
  end

  describe "registration off" do
    it "clears the attendee limit" do
      event = create(:projekt_event, registration_enabled: false, max_attendees: 20)

      expect(event.reload.max_attendees).to be_nil
      expect(event).not_to be_registration_enabled
      expect(event).not_to be_fully_booked
    end

    it "treats a limit of zero as no limit" do
      event = create(:projekt_event, registration_enabled: true, max_attendees: 0)

      expect(event.reload.max_attendees).to be_nil
      expect(event).to be_registration_enabled
    end
  end

  def create_confirmed_registration(event)
    registration = event.projekt_event_registrations.new(
      first_name: "Anna", last_name: "Beispiel", email: "anna@example.org"
    )
    registration.skip_email_confirmation!
    registration.save!
  end
end
