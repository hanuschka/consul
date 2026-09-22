class MunicipalPlan < ApplicationRecord
  include Mappable
  include Searchable

  STATUSES = %w[draft published archived].freeze

  FIRST_PUBLISHED_VERSION = "1.0".freeze

  MAX_DISTRICTS = 4

  # Everything an Entwurf may still be missing, and has to carry before it leaves Entwurf.
  RELEASE_REQUIRED_FIELDS = %i[
    short_description
    processing_status
    next_steps
    responsible
    map_location
  ].freeze

  # How long a Vorhaben carries the "neu" or "aktualisiert" badge.
  RECENCY_WINDOW = 30.days

  CONTENT_ATTRIBUTES = %w[
    formal_participation
    informal_participation
    contact_name
    contact_phone
    contact_email
    system_mailbox_email
  ].freeze

  AUDITED_ATTRIBUTES = (CONTENT_ATTRIBUTES + %w[
    internal_notes
    status
    given_order
    responsible_type
    responsible_id
  ]).freeze

  translates :title, touch: true
  translates :short_description, touch: true
  translates :further_information, touch: true
  translates :last_resolution, touch: true
  translates :processing_status, touch: true
  translates :next_steps, touch: true
  translates :costs, touch: true
  translates :formal_participation_reason, touch: true
  translates :informal_participation_reason, touch: true
  translates :contact_role, touch: true
  include Globalizable

  audited only: AUDITED_ATTRIBUTES
  has_associated_audits
  translation_class.class_eval do
    audited associated_with: :globalized_model, only: MunicipalPlan.translated_attribute_names

    def destroy
      run_callbacks :destroy
      true
    end
  end

  belongs_to :responsible, polymorphic: true, optional: true
  belongs_to :released_plan, class_name: "MunicipalPlan", optional: true, inverse_of: :working_copy
  has_one :working_copy, class_name: "MunicipalPlan", foreign_key: :released_plan_id,
    dependent: :destroy, inverse_of: :released_plan

  has_many :district_assignments, class_name: "MunicipalPlan::DistrictAssignment", dependent: :destroy,
    inverse_of: :municipal_plan
  has_many :districts, through: :district_assignments
  has_many :topic_assignments, class_name: "MunicipalPlan::TopicAssignment", dependent: :destroy,
    inverse_of: :municipal_plan
  has_many :topics, through: :topic_assignments, source: :topic
  has_many :links, -> { order(:given_order) }, class_name: "MunicipalPlan::Link", dependent: :destroy,
    inverse_of: :municipal_plan

  has_many :notices, -> { order(created_at: :desc) }, class_name: "MunicipalPlan::Notice",
    dependent: :destroy, inverse_of: :municipal_plan

  accepts_nested_attributes_for :links, allow_destroy: true

  validates :status, inclusion: { in: STATUSES }
  validates_translation :title, presence: true
  validate :districts_within_limit
  validate :release_requirements, unless: :editable_draft?
  validate :released_plan_is_a_released_version

  before_save :apply_version_rules

  scope :published, -> { where(status: "published") }
  scope :released_versions, -> { where(released_plan_id: nil) }
  scope :archived, -> { where(status: "archived") }
  scope :publicly_visible, -> { where(status: %w[published archived]) }
  scope :due_for_archiving, -> { published.released_versions.where(archive_on: ..Date.current) }
  scope :sort_by_content_updated_at, -> { reorder(content_updated_at: :desc, id: :desc) }
  scope :newly_added, -> { where(created_at: RECENCY_WINDOW.ago..) }
  scope :recently_updated, -> {
    where(content_updated_at: (Date.current - RECENCY_WINDOW.in_days.to_i)..)
      .where.not(created_at: RECENCY_WINDOW.ago..)
  }
  # Ordered by a correlated subquery rather than a join: a join would drop every plan that has no
  # translation in the current locale, which silently hides plans instead of sorting them.
  scope :sort_by_title, -> {
    locale = connection.quote(I18n.locale.to_s)

    reorder(Arel.sql(<<~SQL.squish))
      (SELECT t.title FROM municipal_plan_translations t
        WHERE t.municipal_plan_id = municipal_plans.id
        ORDER BY (t.locale = #{locale}) DESC, t.id ASC
        LIMIT 1) ASC NULLS LAST
    SQL
  }
  scope :assigned_to_officer, ->(officer) {
    return none if officer.blank?

    where(
      "(responsible_type = ? AND responsible_id = ?) OR (responsible_type = ? AND responsible_id IN (?))",
      "MunicipalPlan::Officer", officer.id,
      "MunicipalPlan::OfficerGroup", officer.officer_groups.select(:id)
    )
  }
  scope :sorted, -> { order(Arel.sql("given_order IS NULL, given_order ASC, id ASC")) }

  def draft?
    status == "draft"
  end

  def working_copy?
    released_plan_id.present?
  end

  def submitted_for_release?
    submitted_at.present?
  end

  # What the Sachbearbeitung is still free to leave incomplete: an Entwurf nobody has handed in.
  def editable_draft?
    draft? && !submitted_for_release?
  end

  def published?
    status == "published"
  end

  def archived?
    status == "archived"
  end

  # The minor part is a plain counter: 1.9 is followed by 1.10, never by 2.0. The major part only
  # ever moves from 0 to 1, when the plan is published for the first time.
  def next_version
    "#{major_version}.#{minor_version + 1}"
  end

  def major_version
    version.to_s.split(".", 2).first.to_i
  end

  def minor_version
    version.to_s.split(".", 2).last.to_i
  end

  # "neu" and "aktualisiert" are mutually exclusive: a Vorhaben created inside the window is new,
  # not updated, even though its Aktualisierungsdatum also falls inside it.
  def newly_added?
    created_at.present? && created_at >= RECENCY_WINDOW.ago
  end

  def recently_updated?
    return false if newly_added?
    return false if content_updated_at.blank?

    content_updated_at >= Date.current - RECENCY_WINDOW.in_days.to_i
  end

  # An archived Vorhaben carries no recency badges: its dates lie in the past by definition.
  def badges
    [
      (:new if newly_added? && !archived?),
      (:updated if recently_updated? && !archived?),
      (:formal_participation if formal_participation?),
      (:informal_participation if informal_participation?)
    ].compact
  end

  def searchable_values
    searchable_globalized_values
  end

  def searchable_translations_definitions
    {
      title => "A",
      short_description => "B",
      last_resolution => "C",
      processing_status => "C",
      next_steps => "C",
      further_information => "D"
    }
  end

  def register_content_change!
    update_columns(content_updated_at: Date.current, version: next_version)
  end

  # Editorial order is neither content nor a release: it is written past validations, callbacks
  # and the Versionsnummer.
  # Archives every Vorhaben whose Archivdatum has come, but only where the instance asked for it.
  def self.apply_due_archiving!
    return [] unless Setting["municipal_plans.auto_archive"].present?

    due_for_archiving.to_a.each { |plan| plan.update!(status: "archived") }
  end

  def self.apply_editorial_order(ordered_ids)
    transaction do
      ordered_ids.each_with_index do |id, index|
        where(id: id).update_all(given_order: index + 1)
      end
    end
  end

  def self.content_attribute_names
    CONTENT_ATTRIBUTES + translated_attribute_names.map(&:to_s)
  end

  private

    def content_change?
      (changed & self.class.content_attribute_names).any?
    end

    def apply_version_rules
      self.content_updated_at = Date.current if content_change?

      if becoming_published?
        self.version = FIRST_PUBLISHED_VERSION
      elsif content_change? && !new_record?
        self.version = next_version
      end
    end

    def becoming_published?
      status == "published" && status_changed? && major_version.zero?
    end

    # One Vorhaben carries at most one pending version, never a chain of them.
    def released_plan_is_a_released_version
      return if released_plan.blank? || released_plan.released_plan_id.blank?

      errors.add(:base, I18n.t("activerecord.errors.models.municipal_plan.nested_working_copy"))
    end

    def release_requirements
      RELEASE_REQUIRED_FIELDS.each do |field|
        next if release_value_present?(public_send(field))

        errors.add(:base, I18n.t("activerecord.errors.models.municipal_plan.release_required",
                                 field: self.class.human_attribute_name(field)))
      end

      districts_are_present
      topics_are_present
    end

    # An emptied CKEditor leaves markup behind, which would otherwise pass as a filled field.
    def release_value_present?(value)
      return value.present? unless value.is_a?(String)

      ActionController::Base.helpers.strip_tags(value).tr("\u00A0", " ").strip.present?
    end

    def topics_are_present
      return if topic_assignments.reject(&:marked_for_destruction?).any?

      errors.add(:base, I18n.t("activerecord.errors.models.municipal_plan.topics_required"))
    end

    def districts_within_limit
      return if district_assignments.reject(&:marked_for_destruction?).size <= MAX_DISTRICTS

      errors.add(:base, I18n.t("activerecord.errors.models.municipal_plan.too_many_districts",
                               count: MAX_DISTRICTS))
    end

    def districts_are_present
      return if district_assignments.reject(&:marked_for_destruction?).any?

      errors.add(:base, I18n.t("activerecord.errors.models.municipal_plan.districts_required"))
    end
end
