class ProjektEventRegistration < ApplicationRecord
  belongs_to :projekt_event
  belongs_to :user, optional: true

  validates :first_name, :last_name, :email, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }

  scope :confirmed, -> { where(status: "confirmed") }
  scope :waitlisted, -> { where(status: "waitlisted") }

  before_create :assign_status
  after_destroy :promote_next_waitlisted

  def guest?
    user_id.blank?
  end

  def display_name
    "#{first_name} #{last_name}"
  end

  private

    def assign_status
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
end
