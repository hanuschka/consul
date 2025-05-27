class ProjektPhase::PointOfInterestPhase < ProjektPhase
  has_many :projekt_point_of_interest_categories, foreign_key: :projekt_phase_id,
    dependent: :destroy, inverse_of: :projekt_phase
  has_many :projekt_point_of_interest_pins, foreign_key: :projekt_phase_id,
    dependent: :destroy, inverse_of: :projekt_phase

  after_create :copy_map_settings_from_projekt

  def phase_activated?
    active?
  end

  def name
    "point_of_interest_phase"
  end

  def resources_name
    "projekt_point_of_interest_pins"
  end

  def resource_count
    projekt_point_of_interest_pins.count
  end

  def admin_nav_bar_items
    %w[naming map projekt_point_of_interest_categories projekt_point_of_interest_pins map_resources_overview]
  end

  def settings_in_tabs
    {
      "option.general.max_pins_per_user" => :number_field
    }
  end

  def safe_to_destroy?
    projekt_point_of_interest_pins.empty?
  end

  def max_pins_per_user
    option("general.max_pins_per_user").to_i
  end

  private

    def phase_specific_permission_problems(user, location)
      return :organization if user.organization?
      return :max_pins_reached if max_pins_reached?(user)
    end

    def max_pins_reached?(user)
      return false if max_pins_per_user.zero?
      projekt_point_of_interest_pins.where(user: user).count >= max_pins_per_user
    end
end
