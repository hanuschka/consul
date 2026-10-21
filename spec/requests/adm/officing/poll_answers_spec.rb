require "rails_helper"

describe "Adm officing booth votes", type: :request do
  let(:voting_phase) { create(:projekt_phase, :voting_phase) }
  let(:poll) { create(:poll, projekt_phase: voting_phase) }
  let(:question) { create(:poll_question, poll: poll, given_order: 1) }
  let(:officer) { create(:administrator).user }
  let(:offline_user) { create(:user) }
  let(:target_locale) { (I18n.available_locales - [I18n.default_locale]).first }

  let!(:answer) do
    Globalize.with_locale(I18n.default_locale) do
      create(:poll_question_answer, question: question, title: "Source title", given_order: 1)
    end
  end

  before do
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
    allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)

    allow_any_instance_of(ProjektPhase::VotingPhase).to receive(:permission_problem).and_return(nil)

    Globalize.with_locale(target_locale) { answer.update!(title: "Translated title") }

    officing_manager = OfficingManager.create!(user: officer)
    OfficingManagerAssignment.create!(officing_manager: officing_manager, projekt_phase: voting_phase)

    login_as(officer)
  end

  def record_vote(title)
    post adm_officing_voting_phase_poll_answers_path(voting_phase,
                                                     offline_user_id: offline_user.id,
                                                     question_id: question.id,
                                                     question_answer_id: answer.id,
                                                     answer: title)
  end

  it "links a booth vote to the answer it was recorded against" do
    record_vote("Source title")

    vote = question.answers.find_by(author: offline_user)
    expect(vote.question_answer).to eq answer
    expect(answer.total_votes).to eq 1
  end

  it "links a booth vote recorded under a translated title to the same answer" do
    record_vote("Translated title")

    vote = question.answers.find_by(author: offline_user)
    expect(vote.question_answer).to eq answer
    expect(answer.total_votes).to eq 1
  end

  it "shows the vote as recorded on the officing desk" do
    record_vote("Source title")

    get officing_desk_adm_officing_voting_phase_path(voting_phase,
                                                     offline_user_id: offline_user.id,
                                                     question_id: question.id)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t("adm.officing.voting_phases.poll_question.revoke"))
  end
end
