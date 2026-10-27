require "rails_helper"

describe "Event registration settings in /adm", type: :request do
  let(:admin) { create(:administrator).user }
  let(:phase) { create(:projekt_phase, type: "ProjektPhase::EventPhase") }
  let(:event) { create(:projekt_event, projekt_phase: phase, registration_enabled: false) }

  before do
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
    allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)
    login_as(admin)
  end

  def update_registration(params)
    patch adm_projekts_phase_projekt_event_path(phase, event, section: "registration"),
          params: { projekt_event: params }
  end

  it "saves registration without an attendee limit" do
    update_registration(registration_enabled: "1", max_attendees: "")

    expect(response).to redirect_to adm_projekts_phase_projekt_event_path(phase, event)
    expect(event.reload).to be_registration_enabled
    expect(event.max_attendees).to be_nil
  end

  it "saves registration with an attendee limit" do
    update_registration(registration_enabled: "1", max_attendees: "25")

    expect(event.reload).to be_registration_enabled
    expect(event.max_attendees).to eq 25
  end

  it "drops the attendee limit when registration is switched off" do
    event.update!(registration_enabled: true, max_attendees: 25)

    update_registration(registration_enabled: "0", max_attendees: "25")

    expect(event.reload).not_to be_registration_enabled
    expect(event.max_attendees).to be_nil
  end

  context "registration without an attendee limit" do
    before do
      event.update!(registration_enabled: true, max_attendees: nil)
      registration = event.projekt_event_registrations.new(
        first_name: "Anna", last_name: "Beispiel", email: "anna@example.org"
      )
      registration.skip_email_confirmation!
      registration.save!
    end

    it "shows the event as unlimited" do
      get adm_projekts_phase_projekt_event_path(phase, event)

      expect(response).to be_successful
      expect(response.body).to include I18n.t("adm.projekts.projekt_events.show.unlimited")
    end

    it "lists and exports the registrations" do
      get adm_projekts_phase_projekt_event_registrations_path(phase, event)

      expect(response).to be_successful
      expect(response.body).to include "Anna Beispiel"

      get adm_projekts_phase_projekt_event_registrations_path(phase, event, format: :csv)

      expect(response.body).to include "anna@example.org"
    end
  end
end
