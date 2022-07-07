class ProjektPhase::QuestionPhase < ProjektPhase
  def phase_activated?
    (
      ProjektSetting.find_by(projekt_id: projekt.id, key: 'projekt_feature.questions.show_questions_list').enabled? &&
      projekt.questions.any?
    )
  end

  def active?
    phase_activated?
  end

  def name
    'question_phase'
  end

  def resources_name
    'projekt_questions'
  end

  def default_order
    3
  end
end
