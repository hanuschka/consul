require "rails_helper"

describe Polls::MapPointsFeatureCollection do
  let(:poll) { create(:poll) }
  let(:question) { create(:poll_question, :map_points, poll: poll) }

  def place(author, latitude, longitude)
    answer = question.answers.find_by(author: author) ||
             question.answers.new(author: author).tap(&:save_and_record_voter_participation)

    answer.map_points.create!(latitude: latitude, longitude: longitude)
  end

  it "collects the pins of every participant" do
    place(create(:user), 50.90, 7.10)
    place(create(:user), 50.91, 7.11)

    features = described_class.new(question).call["features"]

    expect(features.size).to eq(2)
    expect(features.map { |feature| feature["geometry"]["coordinates"] })
      .to eq([[7.10, 50.90], [7.11, 50.91]])
  end

  it "keeps several pins from the same participant" do
    author = create(:user)
    place(author, 50.90, 7.10)
    place(author, 50.92, 7.12)

    expect(described_class.new(question).call["features"].size).to eq(2)
  end

  it "exposes nothing about the author" do
    place(create(:user), 50.90, 7.10)

    properties = described_class.new(question).call["features"].first["properties"]

    expect(properties.keys).to eq(["id"])
  end

  it "returns latitude/longitude pairs for the heat layer" do
    place(create(:user), 50.90, 7.10)

    expect(described_class.new(question).coordinates).to eq([[50.90, 7.10]])
  end

  it "returns an empty collection for a question without pins" do
    collection = described_class.new(question)

    expect(collection.call).to eq("type" => "FeatureCollection", "features" => [])
    expect(collection.coordinates).to eq([])
  end

  it "ignores pins belonging to another question" do
    other_question = create(:poll_question, :map_points, poll: poll)
    other_answer = other_question.answers.new(author: create(:user))
    other_answer.save_and_record_voter_participation
    other_answer.map_points.create!(latitude: 48.1, longitude: 11.6)

    place(create(:user), 50.90, 7.10)

    expect(described_class.new(question).coordinates).to eq([[50.90, 7.10]])
  end
end
