class ProjektPhase::QuestionPhase < ProjektPhase
  def phase_activated?
    # projekt.questions.any?
    active?
  end

  def name
    "question_phase"
  end

  def resources_name
    "projekt_questions"
  end

  def default_order
    3
  end
end
