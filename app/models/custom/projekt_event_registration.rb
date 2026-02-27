class ProjektEventRegistration < ApplicationRecord
  belongs_to :projekt_event
  belongs_to :user, optional: true

  validates :user_id, uniqueness: { scope: :projekt_event_id }, allow_nil: true
  validates :first_name, :last_name, :email, presence: true, if: -> { user_id.blank? }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :email, uniqueness: { scope: :projekt_event_id, case_sensitive: false }, if: -> { user_id.blank? && email.present? }

  scope :confirmed, -> { where(status: "confirmed") }
  scope :waitlisted, -> { where(status: "waitlisted") }

  before_create :assign_status
  after_destroy :promote_next_waitlisted

  def guest?
    user_id.blank?
  end

  def display_name
    guest? ? "#{first_name} #{last_name}" : user.name
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
        next_registration&.update!(status: "confirmed")
      end
    end
end
