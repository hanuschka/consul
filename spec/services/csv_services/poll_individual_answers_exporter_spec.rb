require "rails_helper"

describe CsvServices::PollIndividualAnswersExporter do
  let(:poll) { create(:poll) }
  let(:source) { create(:poll_question, poll: poll) }
  let(:bundle) { create(:poll_question, :bundle, poll: poll, contextualize_by_poll_question_id: source.id) }
  let!(:template) { create(:poll_question, :map_points, poll: poll, parent_question: bundle, given_order: 1) }

  before do
    create(:poll_question_answer, question: source, title: "Radwege")
    bundle.regenerate_contexted_clones
  end

  it "lists the pin coordinates of a map answer and names its measure" do
    map_question = template.contexted_variants.first
    answer = map_question.answers.new(author: create(:user))
    answer.save_and_record_voter_participation
    answer.map_points.create!(latitude: 51.52, longitude: 6.92)
    answer.map_points.create!(latitude: 51.53, longitude: 6.93)

    rows = CSV.parse(described_class.call(poll), col_sep: ";", headers: true)
    row = rows.find { |csv_row| csv_row["Frage"] == "#{map_question.title} (Radwege)" }

    expect(row["Antwort"]).to eq "51.52, 6.92; 51.53, 6.93"
  end
end
