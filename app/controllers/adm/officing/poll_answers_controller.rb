class Adm::Officing::PollAnswersController < Adm::Officing::BaseController
  include Adm::Officing::VotingPhaseScoped
  include ResolvesSubmittedQuestionAnswer

  before_action :load_voting_phase
  before_action :verify_assignment
  before_action :load_offline_user
  before_action :load_question

  def create
    authorize :base, policy_class: Adm::Officing::BasePolicy

    @answer = @question.find_or_initialize_user_answer(@offline_user, submitted_question_answer)
    @answer.answer_weight = validated_answer_weight
    @answer.officing_manager_id = @officing_manager.id

    @answer.touch if @answer.persisted?
    ensure_voter if @answer.save

    redirect_to officing_desk_adm_officing_voting_phase_path(
      @voting_phase, offline_user_id: @offline_user.id, question_id: redirect_question_id
    ), status: :see_other
  end

  def update_open_answer
    authorize :base, policy_class: Adm::Officing::BasePolicy

    @answer = @question.find_or_initialize_user_answer(@offline_user, @question.open_question_answer)
    @answer.officing_manager_id = @officing_manager.id
    @answer.answer_weight = 1 if @answer.new_record?
    @answer.open_answer_text = params[:open_answer_text]

    ensure_voter if @answer.save

    redirect_to officing_desk_adm_officing_voting_phase_path(
      @voting_phase, offline_user_id: @offline_user.id, question_id: redirect_question_id
    ), status: :see_other
  end

  def destroy
    authorize :base, policy_class: Adm::Officing::BasePolicy

    @answer = @question.answers.find_by!(author: @offline_user, id: params[:id])
    poll = @answer.poll

    @answer.destroy!

    if @offline_user.poll_answers.where(question_id: poll.question_ids).none?
      Poll::Voter.find_by(user: @offline_user, poll: poll, origin: "booth")&.destroy!
    end

    redirect_to officing_desk_adm_officing_voting_phase_path(
      @voting_phase, offline_user_id: @offline_user.id, question_id: redirect_question_id
    ), status: :see_other
  end

  private

    def load_question
      @question = @voting_phase.poll.questions.find(params[:question_id])
    end

    def redirect_question_id
      @question.parent_question_id || @question.id
    end

    def validated_answer_weight
      weight = params[:answer_weight].to_i
      max = @question.max_votes || 1
      weight.clamp(1, max)
    end

    def ensure_voter
      poll = @question.poll
      Poll::Voter.find_by(user: @offline_user, poll: poll) ||
        Poll::Voter.create!(
          user: @offline_user,
          poll: poll,
          origin: "booth",
          officing_manager: @officing_manager
        )
    end
end
