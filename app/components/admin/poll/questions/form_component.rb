class Admin::Poll::Questions::FormComponent < ApplicationComponent
  include TranslatableFormHelper
  include GlobalizeHelper
  attr_reader :question, :url

  #delegate :can?, to: :helpers
  delegate :can?, :ck_editor_class, :current_user, to: :helpers #custom

  def initialize(question, url:)
    @question = question
    @url = url
  end

  private

    def bundle_question?
      params[:bundle_question] == "true"
    end

    def nested_question?
      params[:parent_question_id].present? || @question.parent_question_id.present?
    end

    def select_options
      Poll.all.select { |poll| can?(:create, Poll::Question.new(poll: poll)) }.map do |poll|
        [poll.name, poll.id]
      end
    end

    def select_options_for_context_sources
      poll_questions_for_context_sources.map{ |pq| [pq.title, pq.id] }
    end

    private

      def poll_questions_for_context_sources
        return [] unless @question.poll.present?

        @poll_questions_for_context_sources ||=
          @question.poll.questions.where.not(id: @question.id)
                   .joins(:votation_type)
                   .where(votation_types: { vote_type: :multiple })
      end
end
