require "rails_helper"

describe "Projekt event registrations", type: :request do
  let(:projekt_event) { create(:projekt_event, max_attendees: 10) }

  def register(extra = {})
    post projekt_event_projekt_event_registrations_path(projekt_event),
         params: {
           projekt_event_registration: {
             first_name: "Anna", last_name: "Beispiel", email: "anna@example.org"
           }.merge(extra)
         }
  end

  it "creates a registration for an ordinary submission" do
    expect { register }.to change { ProjektEventRegistration.count }.by(1)
  end

  it "silently drops a submission that fills the honeypot" do
    expect { register(subtitle: "http://spam.example") }
      .not_to change { ProjektEventRegistration.count }

    expect(response).to have_http_status(:ok)
  end

  it "sends no mail when the honeypot is filled" do
    expect { register(subtitle: "bot") }
      .not_to change { ActiveJob::Base.queue_adapter.enqueued_jobs.count }
  end

  it "does not reject a submission made quickly, since the timestamp check is off" do
    expect { register }.to change { ProjektEventRegistration.count }.by(1)

    expect(flash[:error]).to be_blank
  end

  it "keeps accepting a second registration in the same session" do
    register
    other_event = create(:projekt_event, max_attendees: 10)

    expect {
      post projekt_event_projekt_event_registrations_path(other_event),
           params: { projekt_event_registration: {
             first_name: "Bo", last_name: "Beispiel", email: "bo@example.org"
           } }
    }.to change { ProjektEventRegistration.count }.by(1)
  end
end
