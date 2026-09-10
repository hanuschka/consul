require_dependency Rails.root.join("app", "controllers", "polls", "questions_controller").to_s

class Polls::QuestionsController < ApplicationController
  include GuestUsers

  def answer
    return head(:bad_request) if @question.map_points?

    @question_answer = @question.question_answers.find(params[:question_answer_id])
    weight = params[:answer_weight].presence || 1

    # The maximum the question allows, checked before the write rather than only in
    # the button that would have been disabled. A repeated POST, a form left open in
    # a second tab or any other client reached this action and was recorded, and an
    # extra row is indistinguishable from a vote once it is in.
    #
    # Answered by re-rendering rather than by an error: the citizen is looking at
    # buttons that do not match the state they are refused against, and the partial
    # is what corrects them.
    if !answer_allowed?(weight)
      return respond_to { |format| format.js { render "polls/questions/answers" } }
    end

    @answer = @question.find_or_initialize_user_answer(current_user, @question_answer)
    @answer.answer_weight = weight
    @answer.save_and_record_voter_participation

    unless providing_an_open_answer?(@answer)
      @answer_updated = "answered"
    end

    resolve_wizard_has_next

    respond_to do |format|
      format.js { render "polls/questions/answers" }
    end
  end

  def add_map_point
    return head(:bad_request) unless @question.map_points?

    latitude = params[:latitude]
    longitude = params[:longitude]

    if latitude.blank? || longitude.blank?
      return render json: { error: "missing_coordinates" }, status: :unprocessable_entity
    end

    # An area the portal drew but this host cannot test — Polls::MapPointBoundary
    # needs the GEOS extension for that, and #contains? raises without it rather than
    # answering. Refused as a request that cannot be served instead of raising: a 500
    # here is a map that stops responding to clicks with nothing said about why.
    if !boundary.usable?
      return render json: { error: "boundary_unavailable" }, status: :unprocessable_entity
    end

    unless boundary.contains?(latitude, longitude)
      return render json: { error: "outside_boundary" }, status: :unprocessable_entity
    end

    answer = nil
    limit_reached = false

    Poll::Answer.transaction do
      lock_map_points_for_current_user
      answer = map_points_answer

      if answer.present? && answer.map_points.count >= @question.max_map_points
        limit_reached = true
      else
        answer ||= create_map_points_answer
        answer.map_points.create!(latitude: latitude, longitude: longitude)
      end
    end

    if limit_reached
      return render json: { error: "limit_reached" }, status: :unprocessable_entity
    end

    render json: map_points_payload(answer.reload)
  rescue ActiveRecord::RecordInvalid
    render json: { error: "invalid_coordinates" }, status: :unprocessable_entity
  end

  def remove_map_point
    return head(:bad_request) unless @question.map_points?

    answer = map_points_answer
    map_point = answer&.map_points&.find_by(id: params[:map_point_id])

    return head(:not_found) if map_point.blank?

    map_point.destroy!

    if answer.map_points.reload.empty?
      answer.destroy_and_remove_voter_participation
      return render json: map_points_payload(nil)
    end

    render json: map_points_payload(answer)
  end

  def update_open_answer
    # The free-text option counts against a multiple question's maximum like any
    # other, and this action writes a row like any other. The box is not offered past
    # the maximum, so reaching here is a stale form or a second client.
    if open_answer_params[:open_answer_text].present? &&
        !answer_allowed_for?(open_answer_params[:answer])
      return respond_to { |format| format.js { render "polls/questions/answers" } }
    end

    if open_answer_params[:open_answer_text].present?
      @answer = @question.find_or_initialize_user_answer(current_user, @question.open_question_answer)
      @answer.save_and_record_voter_participation if @answer.new_record?

      if @answer.update(open_answer_text: open_answer_params[:open_answer_text])
        @open_answer_updated = true
      end
    else
      @answer = @question.answers.find_by(author: current_user,
                                          question_answer: @question.open_question_answer)
      @answer.destroy_and_remove_voter_participation if @answer.present?
    end

    resolve_wizard_has_next

    respond_to do |format|
      format.js { render "polls/questions/answers" }
    end
  end

  # Which question follows this one, decided here rather than in the browser. The
  # order, the contexted clones, the branching and the answer that ends a ballot are
  # all Polls::BallotTraversalQuery's, so the page and the WhatsApp bot walk one
  # implementation of them instead of two — the JS worked them out from a map of the
  # whole poll, which meant every rule about which questions a citizen is shown
  # existed twice.
  #
  # Answers with the question's own markup as well as its id, so a step costs one
  # request rather than one to ask and another to fetch. `has_next` travels with it
  # because the button under it says either "next question" or "finish", and only
  # this side can tell which.
  def wizard_next
    return head(:not_found) if !wizard_navigable?(@question)
    return head(:forbidden) if !wizard_readable?(@question)

    following = traversal.next_after(@question)

    return render(json: { question_id: nil }) if following.blank?

    has_next = traversal.next_after?(following)

    render json: {
      question_id: following.id,
      has_next: has_next,
      html: render_to_string(
        partial: "polls/wizard_item",
        layout: false,
        locals: { question: following, has_next: has_next }
      )
    }
  end

  def csv_answers_streets
    question = Poll::Question.find(params[:id])

    respond_to do |format|
      format.csv do
        CsvJobs::PollQuestionAnswersStreetsExporterJob.perform_later(current_user.id, question.id)
      end
    end
  end

  def csv_answers_votes
    question = Poll::Question.find(params[:id])

    respond_to do |format|
      format.csv do
        send_data CsvServices::PollQuestionAnswersVotesExporter.new(question).call,
          filename: "question_#{question.id}_answers_votes_#{Time.zone.today.strftime("%d/%m/%Y")}.csv"
      end
    end
  end

  private

    def boundary
      @boundary ||= Polls::MapPointBoundary.new(@question)
    end

    def lock_map_points_for_current_user
      Poll::Answer.connection.execute(
        "SELECT pg_advisory_xact_lock(#{@question.id.to_i}, #{current_user.id.to_i})"
      )
    end

    def map_points_answer
      @question.answers.find_by(author: current_user)
    end

    def create_map_points_answer
      answer = @question.answers.new(author: current_user)
      answer.save_and_record_voter_participation
      answer
    end

    def map_points_payload(answer)
      map_points = answer&.map_points.to_a

      {
        max_map_points: @question.max_map_points,
        remaining: @question.max_map_points - map_points.size,
        features: {
          "type" => "FeatureCollection",
          "features" => map_points.map(&:to_feature)
        }
      }
    end

    def open_answer_params
      params.require(:poll_answer).permit(:answer, :open_answer_text)
    end

    def answer_allowed?(weight)
      answer_allowed_for?(params[:answer], weight: weight)
    end

    def answer_allowed_for?(title, weight: 1)
      ::Polls::AnswerAllowanceQuery.call(
        question: @question, user: current_user, title: title, weight: weight
      )
    end

    def providing_an_open_answer?(answer)
      @question.open_question_answer.present? &&
        @question.open_question_answer.id == answer.question_answer_id
    end

    def wizard_navigable?(question)
      question.parent_question_id.nil? && question.contextualize_by_poll_question_id.nil?
    end

    # Whether the question just answered is still followed by another, for the button
    # under it. Asked after every recorded answer because an answer is what changes
    # it: it may branch past the rest, end the ballot, or reveal a question
    # contextualised by the option chosen. Nil outside a wizard, and for a nested
    # sub-question, which is not a step of its own on the page.
    def resolve_wizard_has_next
      return if !@question.poll.in_wizard_mode?
      return if !wizard_navigable?(@question)

      @wizard_has_next = traversal.next_after?(@question)
    end

    def wizard_readable?(question)
      projekt = question.poll.projekt

      projekt.present? && projekt.visible_for?(current_user)
    end

    # Guest users answer polls too, and a guest is a User like any other by the time
    # this runs — GuestUsers signs one in on the poll page — so the traversal reads
    # their answers the same way it reads anyone's.
    def traversal
      @traversal ||= ::Polls::BallotTraversalQuery.for(
        poll: @question.poll,
        user: current_user,
        order_seed: helpers.poll_participant_order_seed
      )
    end
end
