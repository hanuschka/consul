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

  describe "a multiple-choice question answered by a user without a stored locale" do
    let(:question) do
      create(:poll_question, poll: poll, given_order: 1,
                             votation_type: VotationType.new(vote_type: :multiple, max_votes: 2))
    end

    before { participant.update_column(:locale, nil) }

    it "records the vote" do
      vote("Source title")

      expect(response).to have_http_status(:ok)
      expect(question.answers.count).to eq 1
    end

    context "as a guest in a guest phase" do
      let(:participant) { create(:user, guest: true) }

      before { poll.projekt_phase.update!(user_status: "guest", active: true) }

      it "records the vote" do
        vote("Source title")

        expect(response).to have_http_status(:ok)
        expect(question.answers.count).to eq 1
      end
    end
  end

  describe "a guest in a guest phase" do
    let(:participant) { create(:user, guest: true) }

    before { poll.projekt_phase.update!(user_status: "guest", active: true) }

    it "cannot vote while the poll is in test mode" do
      poll.update!(live: false)

      vote("Source title")

      expect(question.answers.count).to eq 0
    end

    it "can vote once the poll is released" do
      poll.update!(live: false)
      poll.update!(live: true)

      vote("Source title")

      expect(response).to have_http_status(:ok)
      expect(question.answers.count).to eq 1
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

    describe "re-rendering the answers" do
      let(:rerender) { ".html(\"" }

      it "keeps the textarea when the text is first stored" do
        submit_open_answer("Other", "first thoughts")

        expect(response.body).not_to include rerender
        expect(response.body).to include "js-question-answered"
      end

      it "keeps the textarea when the text is updated" do
        submit_open_answer("Other", "first thoughts")
        submit_open_answer("Other", "second thoughts")

        expect(response.body).not_to include rerender
      end

      it "re-renders when the text replaces another chosen option" do
        vote("Source title")
        submit_open_answer("Other", "first thoughts")

        expect(question.answers.find_by(author: participant).question_answer).to eq open_answer
        expect(response.body).to include rerender
        expect(response.body).to include "$liveForm.detach()"
      end

      it "re-renders when the text is cleared" do
        submit_open_answer("Other", "first thoughts")
        submit_open_answer("Other", "")

        expect(response.body).to include rerender
      end

      context "with a multiple question" do
        before { question.update!(votation_type: VotationType.new(vote_type: :multiple, max_votes: 2)) }

        it "updates the same row instead of adding a second one" do
          submit_open_answer("Other", "first thoughts")
          submit_open_answer("Other", "second thoughts")

          expect(question.answers.where(author: participant).count).to eq 1
          expect(question.answers.first.open_answer_text).to eq "second thoughts"
        end

        it "keeps the textarea when the text is updated" do
          vote("Source title")
          submit_open_answer("Other", "first thoughts")
          submit_open_answer("Other", "second thoughts")

          expect(response.body).not_to include rerender
        end

        it "keeps the textarea while votes remain" do
          submit_open_answer("Other", "first thoughts")

          expect(response.body).not_to include rerender
        end

        it "re-renders when the text uses the last vote" do
          vote("Source title")
          submit_open_answer("Other", "first thoughts")

          expect(question.answers.where(author: participant).count).to eq 2
          expect(response.body).to include rerender
        end
      end
    end
  end
end
