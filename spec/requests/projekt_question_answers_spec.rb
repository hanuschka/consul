require "rails_helper"

describe "Answering a projekt question", type: :request do
  let(:user) { create(:user) }
  let(:projekt) { Projekt.create!(name: "Projekt") }
  let(:phase) { projekt.projekt_phases.create!(type: "ProjektPhase::QuestionPhase", active: true) }
  let(:question) { ProjektQuestion.create!(projekt_phase: phase, author: user, title: "Wie gefällt Ihnen der Platz?") }
  let!(:yes) { ProjektQuestionOption.create!(question: question, value: "Gut") }
  let!(:no) { ProjektQuestionOption.create!(question: question, value: "Schlecht") }

  before { login_as(user) }

  it "saves the first answer and refreshes the question" do
    post projekt_projekt_question_answers_path(projekt),
         params: { projekt_question_answer: { projekt_question_option_id: yes.id } }, xhr: true

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq "text/javascript"
    expect(ProjektQuestionAnswer.find_by!(user: user, question: question).question_option).to eq yes
  end

  it "saves a changed answer and refreshes the question" do
    answer = ProjektQuestionAnswer.create!(user: user, question: question, question_option: yes)

    patch projekt_projekt_question_answer_path(projekt, answer),
          params: { projekt_question_answer: { projekt_question_option_id: no.id } }, xhr: true

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq "text/javascript"
    expect(answer.reload.question_option).to eq no
  end

  it "counts a new vote once on its option" do
    expect do
      post projekt_projekt_question_answers_path(projekt),
           params: { projekt_question_answer: { projekt_question_option_id: yes.id } }, xhr: true
    end.to change { yes.reload.answers_count }.by(1)
  end

  context "as a guest in a guest phase" do
    let(:guest) { create(:user, guest: true) }

    before do
      phase.update!(user_status: "guest")
      login_as(guest)
    end

    it "saves the vote" do
      post projekt_projekt_question_answers_path(projekt),
           params: { projekt_question_answer: { projekt_question_option_id: yes.id } }, xhr: true

      expect(response).to have_http_status(:ok)
      expect(ProjektQuestionAnswer.find_by!(user: guest, question: question).question_option).to eq yes
    end
  end

  context "when the phase has ended while the page was open" do
    before { phase.update!(end_date: 1.day.ago.to_date) }

    it "refuses a new vote as closed and stores nothing" do
      post projekt_projekt_question_answers_path(projekt),
           params: { projekt_question_answer: { projekt_question_option_id: yes.id } }, xhr: true

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body).to eq("error" => "closed")
      expect(ProjektQuestionAnswer.where(question: question)).to be_empty
    end

    it "refuses a changed vote as closed and keeps the old one" do
      answer = ProjektQuestionAnswer.create!(user: user, question: question, question_option: yes)

      patch projekt_projekt_question_answer_path(projekt, answer),
            params: { projekt_question_answer: { projekt_question_option_id: no.id } }, xhr: true

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body).to eq("error" => "closed")
      expect(answer.reload.question_option).to eq yes
    end
  end
end
