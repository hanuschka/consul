class ProjektPhase::VotingPhase < ProjektPhase
  has_many :polls, foreign_key: :projekt_phase_id,
    dependent: :restrict_with_exception, inverse_of: :projekt_phase

  accepts_nested_attributes_for :polls

  after_create(-> { create_poll })

  def phase_activated?
    active?
  end

  def name
    "voting_phase"
  end

  def resources_name
    "polls"
  end

  def default_order
    4
  end

  def resource_count
    polls.for_public_render.count
  end

  def admin_nav_bar_items
    %w[duration naming restrictions settings
       poll_questions
       officing_managers officing_manager_audits
       poll_results
       age_ranges_for_stats]
  end

  def safe_to_destroy?
    polls.empty?
  end

  def poll
    polls.order(:id).first
  end

  private

    def phase_specific_permission_problems(user, location)
      return :organization if user.organization?
    end

    def create_poll
      return if poll.present?

      name_extension = projekt.polls.count > 0 ? projekt.polls.count + 1 : nil

      polls.create!(
        name: [projekt.name, name_extension].compact.join(" "),
        slug: [projekt.name.parameterize, name_extension].compact.join("-")
      )
    end
end
