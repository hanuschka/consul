class ProjektPhase::FormularPhase < ProjektPhase
  has_one :formular, foreign_key: :projekt_phase_id, dependent: :restrict_with_exception,
    inverse_of: :projekt_phase

  after_create :create_formular

  def phase_activated?
    active?
  end

  def name
    "formular_phase"
  end

  def resources_name
    "formular"
  end

  def default_order
    12
  end

  def admin_nav_bar_items
    %w[duration naming restrictions formular settings formular_answers]
  end

  def settings_in_tabs
    settings_in_duration_tab
  end

  def settings_in_duration_tab
    {
      "option.general.primary_formular_cutoff_date" => :date_field
    }
  end

  def safe_to_destroy?
    formular.blank?
  end

  def subscribable?
    false
  end

  private

    def phase_specific_permission_problems(user, location)
      return :past_regular_formular_cutoff_date if formular.past_cutoff_date?

      :submissions_limit_reached if formular.submissions_limit_reached_for?(user)
    end

    def create_formular
      Formular.create!(projekt_phase: self)
    end
end
