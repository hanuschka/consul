class Officing::OfflinePollVotersController < Officing::BaseController
  def verify_user; end

  def find_or_create_user
    if params["skip_verification"].present?
      responding_user = User.create!(
        erased_at:                  Time.current,
        email:                      nil,
        skip_password_validation:   true,
        terms_data_storage:         "1",
        terms_data_protection:      "1",
        terms_general:              "1"
      )

      redirect_to officing_offline_poll_voters_questions_path(params[:poll_id], responding_user_id: responding_user.id)

    else
      unique_stamp = User.new(user_params).prepare_unique_stamp

      if (unique_stamp.blank? ||
          params[:"date_of_birth(1i)"].blank? ||
          params[:"date_of_birth(2i)"].blank? ||
          params[:"date_of_birth(3i)"].blank?)
        flash.now[:error] = "Bitte stellen Sie sicher, dass alle Felder ausgefüllt sind"
        render :verify_user

      else
        responding_user = User.find_by(unique_stamp: unique_stamp)
        responding_user ||= User.find_by(
          first_name: user_params[:first_name],
          last_name: user_params[:last_name],
          plz: user_params[:plz],
          date_of_birth: Date.new(
            params[:"date_of_birth(1i)"].to_i,
            params[:"date_of_birth(2i)"].to_i,
            params[:"date_of_birth(3i)"].to_i
          ).beginning_of_day
        )
        responding_user ||= User.new

        if responding_user.new_record?
          responding_user.assign_attributes(user_params)
          responding_user.email = nil
          responding_user.verified_at = Time.current
          responding_user.erased_at = Time.current
          responding_user.password = "Aa1" + (0...17).map { ("a".."z").to_a[rand(26)] }.join
          responding_user.terms_data_storage = "1"
          responding_user.terms_data_protection = "1"
          responding_user.terms_general = "1"
          responding_user.unique_stamp = unique_stamp
          responding_user.geozone = Geozone.find_with_plz(params[:plz])
          responding_user.save!
        end

        responding_user.verify! if responding_user.verified_at.nil?

        redirect_to officing_offline_poll_voters_questions_path(params[:poll_id], responding_user_id: responding_user.id)
      end
    end
  end

  def questions
    @responding_user = User.find(params[:responding_user_id])
    @poll = Poll.find(params[:poll_id])
    @questions = @poll.questions.for_render.root_questions.sort_for_list

  end

  def record_answer
    @question = Poll::Question.find(params["poll_question_id"])
    @poll = @question.poll
    @responding_user = User.find(params["responding_user_id"])

    @answer = @question.find_or_initialize_user_answer(@responding_user, params[:answer])
    @answer.answer_weight = params[:answer_weight].presence || 1

    @answer.touch if @answer.persisted?
    if @answer.save
      @voter = Poll::Voter.find_by(user: @responding_user, poll: @poll)
      @voter ||= Poll::Voter.create!(origin: "booth",
                                     user: @responding_user,
                                     poll: @poll,
                                     poll_manager: current_user.poll_manager)
      @answer_updated = "answered"
    end
  end

  def update_open_answer
    @responding_user = User.find(params["responding_user_id"])
    @question = Poll::Question.find(params["poll_question_id"])
    @answer = Poll::Answer.find(params["poll_answer_id"])

    if @answer.update(open_answer_text: params["open_answer_text"])
      @open_answer_updated = true
    end

    render "custom/officing/offline_poll_voters/record_answer"
  end

  def remove_answer
    @responding_user = User.find(params["responding_user_id"])
    @question = Poll::Question.find(params["poll_question_id"])
    @answer = Poll::Answer.find(params["poll_answer_id"])

    updated_weight = params["answer_weight_poll_answer_#{@answer.id}"].to_i

    if @question.vote_type == "multiple_with_weight" &&
         updated_weight > 0 &&
         params[:button] != "remove_answer"
      answer = @question.find_or_initialize_user_answer(@responding_user, @answer.answer)
      answer.answer_weight = updated_weight
      answer.save!

    else
      @answer.destroy!
      if @responding_user.poll_answers.where(question_id: @answer.poll.question_ids).none?
        Poll::Voter.find_by(user: @responding_user, poll: @answer.poll, origin: "booth").destroy!
      end

      @answer_updated = "unanswered"
    end
  end

  private

    def user_params
      params
        .slice(:first_name, :last_name, :plz, :"date_of_birth(1i)", :"date_of_birth(2i)", :"date_of_birth(3i)")
        .permit(:first_name, :last_name, :plz, :date_of_birth)
    end
end
