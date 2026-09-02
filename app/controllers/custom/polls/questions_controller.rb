require_dependency Rails.root.join("app", "controllers", "polls", "questions_controller").to_s

class Polls::QuestionsController < ApplicationController
  include GuestUsers

  def answer
    return head(:bad_request) if @question.map_points?

    @answer = @question.find_or_initialize_user_answer(current_user, params[:answer])
    @answer.answer_weight = params[:answer_weight].presence || 1
    @answer.save_and_record_voter_participation
    @question_answer = @question.question_answers.find(params[:question_answer_id])

    unless providing_an_open_answer?(@answer)
      @answer_updated = "answered"
    end

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
    if open_answer_params[:open_answer_text].present?
      @answer = @question.find_or_initialize_user_answer(current_user, open_answer_params[:answer])
      @answer.save_and_record_voter_participation if @answer.new_record?

      if @answer.update(open_answer_text: open_answer_params[:open_answer_text])
        @open_answer_updated = true
      end
    else
      @answer = @question.answers.find_by(author: current_user, answer: open_answer_params[:answer])
      @answer.destroy_and_remove_voter_participation if @answer.present?
    end

    respond_to do |format|
      format.js { render "polls/questions/answers" }
    end
  end

  def wizard_step
    @question = Poll::Question.with_wizard_associations.find(@question.id)

    if !wizard_navigable?(@question)
      return head(:not_found)
    end

    projekt = @question.poll.projekt

    if projekt.blank? || !projekt.visible_for?(current_user)
      return head(:forbidden)
    end

    render partial: "polls/wizard_item", layout: false, locals: { question: @question }
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

    def providing_an_open_answer?(answer)
      @question.open_question_answer.present? && @question.open_question_answer.title == answer.answer
    end

    def wizard_navigable?(question)
      question.parent_question_id.nil? && question.contextualize_by_poll_question_id.nil?
    end
end
