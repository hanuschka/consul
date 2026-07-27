class ProjektPhase::VotingPhase < ProjektPhase
  has_many :polls, foreign_key: :projekt_phase_id,
    dependent: :destroy, inverse_of: :projekt_phase

  accepts_nested_attributes_for :polls

  after_create(-> { create_poll })

  def name
    "voting_phase"
  end

  def sidebar_cta_kind
    :poll if poll.present?
  end

  def resources_name
    "polls"
  end

  def default_order
    4
  end

  def customizable_email_templates
    [
      ["NotificationServiceMailer", "new_poll"]
    ]
  end

  def admin_nav_bar_items
    %w[duration naming restrictions general_settings
       poll_questions
       officing_managers officing_manager_audits
       email_templates
       age_ranges_for_stats]
  end

  def safe_to_destroy?
    polls.empty?
  end

  def after_hide
    polls.each(&:hide)
  end

  def poll
    polls.order(:id).first
  end

  private

    def phase_specific_permission_problems(user, location)
      return :organization if user.organization?
      return :poll_not_live if !poll&.live? && location != :officing
    end

    def create_poll
      return if poll.present?

      name_extension = projekt.polls.count > 0 ? projekt.polls.count + 1 : nil

      new_poll = polls.create!(
        name: [projekt.name, name_extension].compact.join(" "),
        slug: [projekt.name.parameterize, name_extension].compact.join("-"),
        live: false
      )

      copy_projekt_image_to(new_poll)
    end

    def copy_projekt_image_to(new_poll)
      source = projekt.image
      return unless source&.attachment&.attached?

      image = new_poll.build_image(user: source.user, title: source.title)
      image.attachment.attach(source.attachment.blob)
      image.save!(validate: false)
    end
end
