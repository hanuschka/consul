class Officing::PollsController < Officing::BaseController
  include OfficingActions

  def officing_desk
    @poll = Poll.find(params[:id])
    @questions = @poll.questions.for_render.root_questions.sort_for_list
  end

  def record_answer
    @question = Poll::Question.find(params["poll_question_id"])
    @poll = @question.poll
    @offline_user = User.find(params["offline_user_id"])

    @answer = @question.find_or_initialize_user_answer(@offline_user, params[:answer])
    @answer.answer_weight = params[:answer_weight].presence || 1
    @answer.officing_manager_id = current_user.officing_manager.id

    @answer.touch if @answer.persisted?
    if @answer.save
      @voter = Poll::Voter.find_by(user: @offline_user, poll: @poll)
      @voter ||= Poll::Voter.create!(origin: "booth",
                                     user: @offline_user,
                                     poll: @poll,
                                     officing_manager: current_user.officing_manager)
      @answer_updated = "answered"
    end
  end

  def update_open_answer
    @offline_user = User.find(params["offline_user_id"])
    @question = Poll::Question.find(params["poll_question_id"])
    @answer = Poll::Answer.find(params["poll_answer_id"])

    if @answer.update(open_answer_text: params["open_answer_text"])
      @open_answer_updated = true
    end

    render "officing/polls/record_answer"
  end

  def remove_answer
    @offline_user = User.find(params["offline_user_id"])
    @question = Poll::Question.find(params["poll_question_id"])
    @answer = Poll::Answer.find(params["poll_answer_id"])

    updated_weight = params["answer_weight_poll_answer_#{@answer.id}"].to_i

    if @question.vote_type == "multiple_with_weight" &&
         updated_weight > 0 &&
         params[:button] != "remove_answer"
      answer = @question.find_or_initialize_user_answer(@offline_user, @answer.answer)
      answer.answer_weight = updated_weight
      answer.save!

    else
      @answer.destroy!
      if @offline_user.poll_answers.where(question_id: @answer.poll.question_ids).none?
        Poll::Voter.find_by(user: @offline_user, poll: @answer.poll, origin: "booth").destroy!
      end

      @answer_updated = "unanswered"
    end
  end
end
