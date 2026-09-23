class Idea < ApplicationRecord
  include Mappable
  include Imageable
  include Documentable
  include Searchable
  include OnBehalfOfSubmittable
  include Memoable
  include SectionTrackable

  belongs_to :author, class_name: "User", inverse_of: :ideas

  translates :title, :description, :official_answer, touch: true
  include Globalizable
  include MachineTranslatable

  acts_as_paranoid column: :hidden_at
  include ActsAsParanoidAliases

  acts_as_votable

  audited only: %i[video_url on_behalf_of timeframe votes_needed_for_success
                   idea_officer_id idea_category_id admin_accepted_at]
  has_associated_audits
  translation_class.class_eval do
    audited associated_with: :globalized_model,
            only: Idea.translated_attribute_names
  end

  has_many :comments, as: :commentable, inverse_of: :commentable, dependent: :destroy
  belongs_to :category, optional: true, inverse_of: :ideas, foreign_key: :idea_category_id
  belongs_to :officer, optional: true, inverse_of: :ideas, class_name: "Idea::Officer", foreign_key: :idea_officer_id

  delegate :approximated_address, to: :map_location, allow_nil: true

  validates_translation :title, presence: true
  validates_translation :description, presence: true
  validates :resource_terms, acceptance: { allow_nil: false }, on: :create
  validates :author, presence: true

  scope :by_author, ->(author_id) { where(author_id: author_id) }

  scope :sort_by_most_supported, -> { reorder(cached_votes_up: :desc) }
  scope :sort_by_most_commented, -> { reorder(comments_count: :desc) }
  scope :sort_by_newest,         -> { reorder(created_at: :desc) }

  scope :accepted, -> { where.not(admin_accepted_at: nil) }
  scope :pending,  -> { where(admin_accepted_at: nil) }

  scope :active,   -> { accepted.where("admin_accepted_at + (timeframe * interval '1 day') >= ?", Time.zone.now.beginning_of_day) }
  scope :archived, -> { accepted.where("admin_accepted_at + (timeframe * interval '1 day') < ?", Time.zone.now.beginning_of_day) }

  scope :filter_by_status_active,   -> { active }
  scope :filter_by_status_archived, -> { archived }

  scope :filter_by_quorum_reached,     -> { where("cached_votes_up >= votes_needed_for_success") }
  scope :filter_by_quorum_not_reached, -> { where("cached_votes_up < votes_needed_for_success") }

  def self.idea_orders
    %w[most_supported most_commented newest]
  end

  def self.search(terms)
    pg_search(terms)
  end

  def searchable_values
    {
      id.to_s               => "A",
      author&.username      => "B"
    }.merge!(searchable_globalized_values)
  end

  def searchable_translations_definitions
    { title       => "A",
      description => "D" }
  end

  def to_param
    "#{id}-#{title}".parameterize
  end

  def comments_allowed?(user)
    true
  end

  def status
    if in? self.class.active
      "active"
    elsif in? self.class.archived
      "archived"
    elsif in? self.class.pending
      "pending"
    end
  end

  def accepted?
    admin_accepted_at.present?
  end

  def remaining_days
    return if admin_accepted_at.blank? || timeframe.blank?

    ((admin_accepted_at + timeframe.days).to_date - Time.zone.now.to_date).to_i
  end

  def tags
    []
  end

  def section_tracking_section
    "ideas"
  end

  def section_tracking_user
    author
  end
end
