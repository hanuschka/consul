class Adm::Officing::VotingPhasesController < Adm::Officing::BaseController
  include Adm::Officing::VotingPhaseScoped

  before_action :load_voting_phase
  before_action :verify_assignment

  def officing_desk
    authorize :base, policy_class: Adm::Officing::BasePolicy

    @offline_user = User.find(params[:offline_user_id])
    @poll = @voting_phase.poll

    @permission_problem = @voting_phase.permission_problem(@offline_user, location: :officing)

    if @permission_problem.present?
      render "adm/officing/shared/permission_problem" and return
    end

    all_questions = @poll.questions
                        .for_render
                        .root_questions
                        .where(contextualize_by_poll_question_id: nil)
                        .sort_for_list
                        .includes(:question_answers, :votation_type, :context,
                                  nested_questions: [:question_answers, :votation_type])

    @all_user_answers = Poll::Answer
      .where(author: @offline_user, question_id: all_questions.map(&:id))

    @questions = filter_visible_questions(all_questions)

    if params[:question_id].present?
      @current_question = @questions.find { |q| q.id == params[:question_id].to_i }
    end
    @current_question ||= @questions.first

    @current_index = @questions.index(@current_question) || 0
    @prev_question = @current_index > 0 ? @questions[@current_index - 1] : nil
    @next_question = @questions[@current_index + 1]

    if @current_question.present?
      question_ids = [@current_question.id] + @current_question.nested_questions.map(&:id)
      @user_answers_by_question = Poll::Answer
        .where(author: @offline_user, question_id: question_ids)
        .group_by(&:question_id)
    else
      @user_answers_by_question = {}
    end
  end

  private

    def filter_visible_questions(questions)
      answered_titles_by_question = Poll::Answer
        .where(author: @offline_user, question_id: questions.map(&:id))
        .pluck(:question_id, :answer)
        .group_by(&:first)
        .transform_values { |pairs| pairs.map(&:last) }

      questions.select do |question|
        if question.context.present?
          source_question = questions.find { |q| q.question_answers.any? { |qa| qa.id == question.context_id } }
          source_question && (answered_titles_by_question[source_question.id] || []).include?(question.context.title)
        else
          true
        end
      end
    end
end
