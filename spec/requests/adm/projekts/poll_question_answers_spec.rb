require "rails_helper"

describe "Adm poll answer titles", type: :request do
  let(:admin) { create(:administrator).user }
  let(:projekt_phase) { create(:projekt_phase, :voting_phase) }
  let(:poll) { create(:poll, projekt_phase: projekt_phase) }
  let(:question) { create(:poll_question, poll: poll) }
  let(:answer) { create(:poll_question_answer, question: question, title: "Original") }

  before do
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
    allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)
    login_as(admin)
  end

  def rename_answer(locale: nil, extra: {})
    patch adm_projekts_phase_poll_question_poll_question_answer_path(projekt_phase, question, answer,
                                                                     locale: locale),
          params: { poll_question_answer: { title: "Renamed" }.merge(extra) }
  end

  def cast_a_vote
    Poll::Answer.create!(question: question, author: create(:user), answer: answer.title)
    Poll::Voter.create!(poll: poll, user: create(:user), origin: "web")
  end

  it "renames the answer while nobody has voted" do
    rename_answer

    expect(answer.reload.title).to eq "Renamed"
  end

  it "refuses to rename the answer once a vote has been cast on a live poll" do
    cast_a_vote

    rename_answer

    expect(answer.reload.title).to eq "Original"
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include(I18n.t("adm.projekts.poll_question_answers.update.error"))
  end

  it "refuses the rename in every backoffice locale" do
    cast_a_vote

    rename_answer(locale: (SupportedLocales::ADM.keys - [I18n.default_locale]).first)

    expect(answer.reload.title).to eq "Original"
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "keeps the rest of the submitted form when the rename is refused" do
    cast_a_vote

    rename_answer(extra: { description: "Longer explanation" })

    expect(answer.reload.description).to be_blank
    expect(response.body).to include("Longer explanation")
  end
end
