require "rails_helper"

describe "Authoring a map question in /adm", type: :request do
  let(:poll) { create(:poll) }
  let(:projekt_phase) { poll.projekt_phase }
  let(:admin) { create(:administrator).user }

  let(:polygon) do
    {
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
    }
  end

  def question_params(features:, max_votes:)
    {
      poll_question: {
        poll_id: poll.id,
        title: "Where should the bench go?",
        votation_type_attributes: { vote_type: "map_points", max_votes: max_votes },
        map_location_attributes: {
          latitude: 50.9,
          longitude: 7.1,
          zoom: 13,
          rendering_library: "leaflet",
          features: features.to_json
        }
      }
    }
  end

  before { login_as(admin) }

  it "stores the vote type, the pin cap and the boundary polygon" do
    post adm_projekts_phase_poll_questions_path(projekt_phase),
         params: question_params(features: polygon, max_votes: 4)

    question = poll.questions.order(:id).last

    expect(question.map_points?).to be true
    expect(question.max_map_points).to eq(4)
    expect(question.map_location.features["features"].first["geometry"]["type"]).to eq("Polygon")
    expect(Polls::MapPointBoundary.new(question)).to be_restricted
  end

  it "makes the stored boundary reject a pin outside it" do
    post adm_projekts_phase_poll_questions_path(projekt_phase),
         params: question_params(features: polygon, max_votes: 1)

    boundary = Polls::MapPointBoundary.new(poll.questions.order(:id).last)

    expect(boundary.contains?(50.9, 7.1)).to be true
    expect(boundary.contains?(50.9, 8.5)).to be false
  end

  it "leaves placement unrestricted when no polygon was drawn" do
    post adm_projekts_phase_poll_questions_path(projekt_phase),
         params: question_params(features: { "type" => "FeatureCollection", "features" => [] },
                                 max_votes: 2)

    question = poll.questions.order(:id).last

    expect(question.map_points?).to be true
    expect(Polls::MapPointBoundary.new(question)).not_to be_restricted
  end

  it "replaces the boundary when the question is edited" do
    question = create(:poll_question, :map_points, poll: poll)
    question.create_map_location!(
      features: { "type" => "FeatureCollection", "features" => [] },
      latitude: 50.9, longitude: 7.1, zoom: 13,
      rendering_library: :leaflet, skip_masterportal_geocoding: true
    )

    patch adm_projekts_phase_poll_question_path(projekt_phase, question),
          params: {
            poll_question: {
              title: question.title,
              votation_type_attributes: { id: question.votation_type.id,
                                          vote_type: "map_points", max_votes: 2 },
              map_location_attributes: { id: question.map_location.id, features: polygon.to_json }
            }
          }

    question.reload

    expect(question.max_map_points).to eq(2)
    expect(Polls::MapPointBoundary.new(question)).to be_restricted
  end
end
