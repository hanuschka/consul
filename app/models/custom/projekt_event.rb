class ProjektEvent < ApplicationRecord
  include Notifiable
  include Imageable
  include ResourceBelongsToProjekt

  translates :title, :description, :location, touch: true
  include MachineTranslatable

  belongs_to :old_projekt, class_name: "Projekt", foreign_key: "projekt_id" # TODO: remove column after data migration con1538

  delegate :projekt, to: :projekt_phase
  belongs_to :projekt_phase

  has_many :projekt_event_registrations, dependent: :destroy

  validates :title, presence: true
  validates :datetime, presence: true
  validates :max_attendees, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :weblink, format: { with: WebLink::HTTP_SCHEME }, allow_blank: true, if: :weblink_changed?

  before_validation :nullify_zero_max_attendees
  before_validation :clear_max_attendees_without_registration
  before_validation :normalize_weblink

  default_scope { order(datetime: :asc) }

  scope :sort_by_all, -> {
    all
  }

  scope :sort_by_incoming, -> {
    where("COALESCE(end_datetime, datetime) >= ?", Time.zone.now)
  }

  scope :sort_by_past, -> {
    where("COALESCE(end_datetime, datetime) < ?", Time.zone.now)
  }

  scope :with_active_projekt, -> {
    joins(projekt_phase: :projekt).merge(Projekt.activated).merge(ProjektPhase.active)
  }

  def started?
    datetime.present? && datetime <= Time.zone.now
  end

  def attendee_limit?
    max_attendees.present?
  end

  def spots_available
    max_attendees - projekt_event_registrations.confirmed.count
  end

  def fully_booked?
    attendee_limit? && spots_available <= 0
  end

  def registrations_by(user)
    return projekt_event_registrations.none unless user

    projekt_event_registrations.where(user: user)
  end

  def admin_emails_include?(email)
    return false if admin_emails.blank?

    admin_emails.split(",").map { |e| e.strip.downcase }.include?(email.downcase)
  end

  def weblink_url
    WebLink.normalize(weblink)
  end

  private

    def nullify_zero_max_attendees
      self.max_attendees = nil if max_attendees == 0
    end

    def clear_max_attendees_without_registration
      self.max_attendees = nil unless registration_enabled?
    end

    def normalize_weblink
      return if weblink.blank?

      self.weblink = weblink_url || weblink
    end
end
