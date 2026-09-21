class MunicipalPlan < ApplicationRecord
  include Mappable

  STATUSES = %w[draft published archived].freeze

  MAX_DISTRICTS = 4

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

  has_many :district_assignments, class_name: "MunicipalPlan::DistrictAssignment", dependent: :destroy,
    inverse_of: :municipal_plan
  has_many :districts, through: :district_assignments
  has_many :topic_assignments, class_name: "MunicipalPlan::TopicAssignment", dependent: :destroy,
    inverse_of: :municipal_plan
  has_many :topics, through: :topic_assignments, source: :topic
  has_many :links, -> { order(:given_order) }, class_name: "MunicipalPlan::Link", dependent: :destroy,
    inverse_of: :municipal_plan

  accepts_nested_attributes_for :links, allow_destroy: true

  validates :status, inclusion: { in: STATUSES }
  validates :responsible, presence: true
  validates :map_location, presence: true, on: :create
  validates_translation :title, presence: true
  validates_translation :short_description, presence: true
  validates_translation :processing_status, presence: true
  validates_translation :next_steps, presence: true
  validate :topics_are_present
  validate :districts_within_limit
  validate :districts_are_present

  before_save :stamp_content_change, if: :content_change?

  scope :published, -> { where(status: "published") }
  scope :sorted, -> { order(Arel.sql("given_order IS NULL, given_order ASC, id ASC")) }

  def draft?
    status == "draft"
  end

  def published?
    status == "published"
  end

  def archived?
    status == "archived"
  end

  def next_version
    major, minor = version.to_s.split(".", 2)
    major = "1" if major.blank?

    "#{major}.#{minor.to_i + 1}"
  end

  def register_content_change!
    update_columns(content_updated_at: Date.current, version: next_version)
  end

  def self.content_attribute_names
    CONTENT_ATTRIBUTES + translated_attribute_names.map(&:to_s)
  end

  private

    def content_change?
      (changed & self.class.content_attribute_names).any?
    end

    def stamp_content_change
      self.content_updated_at = Date.current
      self.version = next_version unless new_record?
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
