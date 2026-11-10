require "rails_helper"

describe "Poll participation confirmation", type: :request do
  let(:poll) { create(:poll) }
  let(:question) { create(:poll_question, poll: poll, given_order: 1) }
  let(:participant) { create(:administrator).user }
  before do
    create(:poll_question_answer, :open_answer, question: question, title: "Anderes")
    login_as(participant)
  end

  it "removes an open answer that was chosen but left without text" do
    Poll::Answer.create!(question: question, author: participant, answer: "Anderes", open_answer_text: nil)

    post poll_confirm_participation_path(poll), xhr: true

    expect(question.answers.where(author: participant)).to be_empty
  end

  it "keeps an open answer that has text" do
    Poll::Answer.create!(question: question, author: participant, answer: "Anderes", open_answer_text: "Ein Spielplatz")

    post poll_confirm_participation_path(poll), xhr: true

    expect(question.answers.where(author: participant).count).to eq(1)
  end
end
