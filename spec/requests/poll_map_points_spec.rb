require "rails_helper"

describe "Poll map point questions", type: :request do
  let(:poll) { create(:poll) }
  let(:question) { create(:poll_question, :map_points, poll: poll, given_order: 1) }
  # Administrators bypass ProjektPhase#permission_problem, which keeps the setup
  # here about map points rather than about phase permissions.
  let(:participant) { create(:administrator).user }

  def add_boundary
    question.create_map_location!(
      features: {
        "type" => "FeatureCollection",
        "features" => [
          {
            "type" => "Feature",
            "properties" => {},
            "geometry" => {
              "type" => "Polygon",
              "coordinates" => [[[7.0, 50.8], [7.2, 50.8], [7.2, 51.0], [7.0, 51.0], [7.0, 50.8]]]
            }
          }
        ]
      },
      latitude: 50.9,
      longitude: 7.1,
      zoom: 13,
      rendering_library: :leaflet,
      skip_masterportal_geocoding: true
    )
    question.reload
  end

  def place(latitude: 50.9, longitude: 7.1)
    post add_map_point_question_path(question), params: { latitude: latitude, longitude: longitude }
  end

  def payload
    JSON.parse(response.body)
  end

  def points_of(user)
    question.answers.find_by(author: user)&.map_points&.order(:id).to_a
  end

  describe "POST add_map_point" do
    before { login_as(participant) }

    it "stores the pin and reports what is left" do
      expect { place }.to change { Poll::Answer::MapPoint.count }.by(1)

      expect(response).to have_http_status(:ok)
      expect(payload["max_map_points"]).to eq(3)
      expect(payload["remaining"]).to eq(2)
      expect(payload["features"]["features"].first["geometry"]["coordinates"]).to eq([7.1, 50.9])
    end

    it "creates exactly one answer and one voter record for several pins" do
      place(latitude: 50.90, longitude: 7.10)
      place(latitude: 50.91, longitude: 7.11)

      expect(question.answers.where(author: participant).count).to eq(1)
      expect(Poll::Voter.where(poll: poll, user: participant).count).to eq(1)
      expect(points_of(participant).size).to eq(2)
    end

    it "refuses to go past the configured maximum" do
      3.times { |index| place(latitude: 50.90 + (index / 100.0), longitude: 7.1) }

      expect { place }.not_to change { Poll::Answer::MapPoint.count }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(payload["error"]).to eq("limit_reached")
    end

    it "rejects a pin outside the boundary" do
      add_boundary

      expect { place(latitude: 50.9, longitude: 8.5) }.not_to change { Poll::Answer::MapPoint.count }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(payload["error"]).to eq("outside_boundary")
    end

    it "accepts a pin inside the boundary" do
      add_boundary

      expect { place(latitude: 50.9, longitude: 7.1) }.to change { Poll::Answer::MapPoint.count }.by(1)
    end

    it "rejects a request without coordinates" do
      post add_map_point_question_path(question), params: {}

      expect(response).to have_http_status(:unprocessable_entity)
      expect(payload["error"]).to eq("missing_coordinates")
    end

    it "is not available on an option question" do
      option_question = create(:poll_question, poll: poll)

      post add_map_point_question_path(option_question), params: { latitude: 50.9, longitude: 7.1 }

      expect(response).to have_http_status(:bad_request)
    end
  end

  describe "POST answer" do
    before { login_as(participant) }

    # The option validations are skipped for map questions, so this endpoint has to
    # refuse them outright: otherwise it would store arbitrary text as the answer.
    it "refuses map questions" do
      expect do
        post answer_question_path(question), params: { answer: "anything at all" }
      end.not_to change { Poll::Answer.count }

      expect(response).to have_http_status(:bad_request)
    end
  end

  describe "DELETE remove_map_point" do
    before { login_as(participant) }

    it "removes the pin and keeps the answer while others remain" do
      place(latitude: 50.90, longitude: 7.10)
      place(latitude: 50.91, longitude: 7.11)
      first_point = points_of(participant).first

      delete remove_map_point_question_path(question), params: { map_point_id: first_point.id }

      expect(response).to have_http_status(:ok)
      expect(payload["remaining"]).to eq(2)
      expect(points_of(participant).size).to eq(1)
      expect(question.answers.where(author: participant).count).to eq(1)
    end

    it "gives up the answer and the voter record with the last pin" do
      place
      point = points_of(participant).first

      delete remove_map_point_question_path(question), params: { map_point_id: point.id }

      expect(response).to have_http_status(:ok)
      expect(payload["features"]["features"]).to eq([])
      expect(question.answers.where(author: participant)).not_to exist
      expect(Poll::Voter.where(poll: poll, user: participant)).not_to exist
    end

    it "does not touch another participant's pin" do
      place
      other_point = points_of(participant).first

      login_as(create(:administrator).user)
      delete remove_map_point_question_path(question), params: { map_point_id: other_point.id }

      expect(response).to have_http_status(:not_found)
      expect(Poll::Answer::MapPoint.where(id: other_point.id)).to exist
    end
  end

  describe "GET the poll page" do
    it "renders the map for a map question instead of answer buttons" do
      create(:poll_question_answer, question: question, title: "Should not be rendered")
      login_as(participant)

      get poll_path(poll)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("js-poll-map-points")
      expect(response.body).to include("data-max-map-points=\"3\"")
      expect(response.body).not_to include("Should not be rendered")
    end

    it "hands the participant's own pins to the map" do
      login_as(participant)
      place(latitude: 50.9, longitude: 7.1)

      get poll_path(poll)

      expect(response.body).to include("data-map-points")
      expect(response.body).to include("50.9")
    end

    # Pin placement only exists for Leaflet, so a map question renders with Leaflet
    # even where the instance is configured for another library.
    it "renders a leaflet map even when the map location says mapbox" do
      question.create_map_location!(
        latitude: 50.9, longitude: 7.1, zoom: 13,
        rendering_library: :mapbox, skip_masterportal_geocoding: true
      )
      login_as(participant)

      get poll_path(poll)

      expect(response.body).to include("js-poll-map-points-counter")
      expect(response.body).to match(/class="map_location map leaflet/)
      expect(response.body).not_to match(/class="map_location map mapbox/)
    end
  end
end
