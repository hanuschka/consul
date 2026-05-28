class ProjektEventRegistration < ApplicationRecord
  belongs_to :projekt_event
  belongs_to :user, optional: true

  validates :first_name, :last_name, :email, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
  validate :email_uniqueness_per_event, on: :create

  scope :confirmed, -> { where(status: "confirmed") }
  scope :waitlisted, -> { where(status: "waitlisted") }
  scope :pending_confirmation, -> { where(status: "pending_confirmation") }
  scope :active, -> { where(status: %w[confirmed waitlisted]) }

  before_create :generate_confirmation_token
  before_create :assign_status
  after_destroy :promote_next_waitlisted

  def guest?
    user_id.blank?
  end

  def display_name
    "#{first_name} #{last_name}"
  end

  def pending_confirmation?
    status == "pending_confirmation"
  end

  def email_requires_confirmation?(current_user)
    return false if current_user && email.downcase == current_user.email.downcase
    return false if projekt_event.admin_emails_include?(email)

    true
  end

  def confirm_email!
    return unless pending_confirmation?

    self.confirmed_at = Time.current
    assign_final_status
    save!
    self
  end

  private

    def email_uniqueness_per_event
      return if email.blank? || projekt_event.blank?
      return if projekt_event.admin_emails_include?(email)

      existing = projekt_event.projekt_event_registrations
                   .where("LOWER(email) = ?", email.downcase)
                   .where.not(status: "cancelled")
      existing = existing.where.not(id: id) if persisted?

      if existing.exists?
        errors.add(:email, :taken)
      end
    end

    def generate_confirmation_token
      self.confirmation_token = SecureRandom.hex(32)
    end

    def assign_status
      if @skip_email_confirmation
        assign_final_status
      else
        self.status = "pending_confirmation"
      end
    end

    def assign_final_status
      projekt_event.lock!

      if projekt_event.max_attendees.nil? ||
          projekt_event.projekt_event_registrations.confirmed.count < projekt_event.max_attendees
        self.status = "confirmed"
      else
        self.status = "waitlisted"
      end
    end

    def promote_next_waitlisted
      return unless status == "confirmed"

      projekt_event.with_lock do
        next_registration = projekt_event.projekt_event_registrations.waitlisted.order(:created_at).first
        if next_registration
          next_registration.update!(status: "confirmed")
          Mailer.projekt_event_registration_email(next_registration).deliver_later
        end
      end
    end

  public

    def skip_email_confirmation!
      @skip_email_confirmation = true
    end
end
