class ParticapationStats::AiQuestionComponent < ApplicationComponent
  include ActionView::Helpers::TranslationHelper

  def initialize(projekt_phase:)
    @projekt_phase = projekt_phase
    @stat_questions = projekt_phase.stat_questions.by_newest.limit(20)
  end

  def can_ask_questions?
    helpers.can?(:refresh_stats, @projekt_phase)
  end

  def pending_questions
    @stat_questions.select { |q| q.pending? || q.processing? }
  end

  def completed_questions
    @stat_questions.select(&:completed?)
  end

  def has_pending?
    pending_questions.any?
  end
end
