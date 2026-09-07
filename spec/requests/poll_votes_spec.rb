require "rails_helper"

describe "Poll votes", type: :request do
  let(:poll) { create(:poll) }
  let(:question) { create(:poll_question, poll: poll, given_order: 1) }
  let(:participant) { create(:administrator).user }
  let(:target_locale) { (I18n.available_locales - [I18n.default_locale]).first }

  let!(:answer) do
    Globalize.with_locale(I18n.default_locale) do
      create(:poll_question_answer, question: question, title: "Source title", given_order: 1)
    end
  end

  before do
    Globalize.with_locale(target_locale) { answer.update!(title: "Translated title") }
    login_as(participant)
  end

  def vote(title, locale: nil)
    post answer_question_path(question, answer: title, question_answer_id: answer.id, locale: locale),
         xhr: true
  end

  describe "casting a vote" do
    it "links a vote cast in the default locale to the answer" do
      vote("Source title")

      expect(question.answers.count).to eq 1
      expect(question.answers.first.question_answer).to eq answer
      expect(answer.total_votes).to eq 1
    end

    it "links a vote cast in a translated locale to the same answer" do
      vote("Translated title", locale: target_locale)

      expect(question.answers.count).to eq 1
      expect(question.answers.first.question_answer).to eq answer
      expect(answer.total_votes).to eq 1
    end
  end

  describe "open answers" do
    let!(:open_answer) do
      Globalize.with_locale(I18n.default_locale) do
        create(:poll_question_answer, :open_answer, question: question, title: "Other", given_order: 2)
      end
    end

    def submit_open_answer(title, text)
      post update_open_answer_path(question),
           params: { poll_answer: { answer: title, open_answer_text: text }},
           xhr: true
    end

    it "stores the text once and links it to the open answer" do
      submit_open_answer("Other", "first thoughts")

      vote = question.answers.find_by(author: participant)
      expect(vote.question_answer).to eq open_answer
      expect(vote.open_answer_text).to eq "first thoughts"
    end

    it "updates the same row instead of adding a second one" do
      submit_open_answer("Other", "first thoughts")
      submit_open_answer("Other", "second thoughts")

      expect(question.answers.count).to eq 1
      expect(question.answers.first.open_answer_text).to eq "second thoughts"
    end

    it "removes the vote when the text is cleared" do
      submit_open_answer("Other", "first thoughts")
      submit_open_answer("Other", "")

      expect(question.answers.count).to eq 0
    end
  end
end
