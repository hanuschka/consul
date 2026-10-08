class ProjektPhase::MitmachboxPhase < ProjektPhase
  has_many :mitmachbox_participations, foreign_key: :projekt_phase_id,
    dependent: :destroy, inverse_of: :projekt_phase

  def name
    "mitmachbox_phase"
  end

  def resources_name
    "mitmachbox"
  end

  def default_order
    16
  end

  def admin_nav_bar_items
    %w[duration naming general_settings
       mitmachbox_survey mitmachbox_deployments mitmachbox_results]
  end

  def customizable_email_templates
    []
  end

  def subscribable?
    false
  end

  def safe_to_destroy?
    true
  end

  def remote_survey_created?
    mitmachbox_survey_id.present?
  end

  def online_answering_enabled?
    feature?("general.answer_survey_online")
  end

  def online_answering_open?
    online_answering_enabled? && current?
  end

  def answered_by?(user, survey_version_id)
    return false if user.blank? || survey_version_id.blank?

    mitmachbox_participations.exists?(user_id: user.id, survey_version_id: survey_version_id)
  end
end
