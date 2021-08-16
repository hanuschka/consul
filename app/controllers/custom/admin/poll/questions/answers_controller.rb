require_dependency Rails.root.join("app", "controllers", "admin", "poll", "questions", "answers_controller").to_s

class Admin::Poll::Questions::AnswersController < Admin::Poll::BaseController

  private

    def answer_params
      attributes = [:title, :description, :given_order, :question_id, :open_answer,
        documents_attributes: document_attributes]

      params.require(:poll_question_answer).permit(
        *attributes, translation_params(Poll::Question::Answer)
      )
    end
end
