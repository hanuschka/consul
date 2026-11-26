require "rails_helper"

describe "Answering a Kurzumfrage", type: :system do
  let(:user) { create(:user) }
  let(:projekt) { create(:projekt) }
  let(:phase) { projekt.projekt_phases.create!(type: "ProjektPhase::QuestionPhase", active: true) }
  let(:question) { ProjektQuestion.create!(projekt_phase: phase, author: user, title: "Wie gefällt Ihnen der Platz?") }
  let!(:good) { ProjektQuestionOption.create!(question: question, value: "Gut") }
  let!(:bad) { ProjektQuestionOption.create!(question: question, value: "Schlecht") }

  before do
    login_as(user)
    visit page_path(projekt.page.slug)
    expect(page).to have_css(".js-projekt-answer-form")
  end

  def choose_option(value)
    find("label.projekt-question-answer-option", text: value).click
  end

  it "unlocks the options and asks to retry when the vote fails to send" do
    allow_any_instance_of(ProjektQuestionAnswersController).to receive(:create) do |controller|
      controller.head(:internal_server_error)
    end

    choose_option("Gut")

    expect(page).to have_css(".js-projekt-answer-error", text: I18n.t("custom.projekts.projekt_questions.answer_error"))
    expect(page).not_to have_css(".show-loader")
    expect(page).not_to have_css(".js-projekt-answer-form input[type=radio]:disabled")
    expect(page).not_to have_css(".js-projekt-answer-form input[type=radio]:checked")
    expect(ProjektQuestionAnswer.where(question: question)).to be_empty
  end

  it "says that voting has closed when the phase ended while the page was open" do
    phase.update!(end_date: 1.day.ago.to_date)

    choose_option("Gut")

    expect(page).to have_css(".js-projekt-answer-error", text: I18n.t("custom.projekts.projekt_questions.answer_closed"))
    expect(page).not_to have_css(".show-loader")
    expect(page).not_to have_css(".js-projekt-answer-form input[type=radio]:checked")
    expect(ProjektQuestionAnswer.where(question: question)).to be_empty
  end

  it "saves a vote as before" do
    choose_option("Gut")

    expect(page).not_to have_css(".show-loader")
    expect(page).to have_css("label.projekt-question-answer-option.-active", text: "Gut")
    expect(ProjektQuestionAnswer.find_by!(user: user, question: question).question_option).to eq good
  end
end
