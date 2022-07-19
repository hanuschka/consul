class ProjektPhase::QuestionPhase < ProjektPhase
  def phase_activated?
    projekt.questions.any? && !expired?
  end

  def active?
    phase_activated?
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
