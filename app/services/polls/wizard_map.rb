class Polls::WizardMap < ApplicationService
  def initialize(wizard_questions, context_source_ids)
    @wizard_questions = wizard_questions
    @context_source_ids = context_source_ids.to_set
  end

  def call
    @wizard_questions.map do |question|
      {
        id: question.id,
        is_context_source: @context_source_ids.include?(question.id),
        context_answer_id: question.context_id
      }
    end
  end
end
