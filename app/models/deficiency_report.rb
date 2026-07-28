class DeficiencyReport < ApplicationRecord
  include Taggable
  include Mappable
  include Imageable
  include Documentable
  include Searchable
  include OnBehalfOfSubmittable
  include Notifiable
  include Milestoneable
  include Memoable
  include SectionTrackable
  translates :title, touch: true
  translates :description, touch: true
  translates :summary, touch: true
  translates :official_answer, touch: true
  include Globalizable

  acts_as_votable
  acts_as_paranoid column: :hidden_at
  include ActsAsParanoidAliases

  audited only: %i[video_url on_behalf_of cached_votes_up cached_votes_down
                   deficiency_report_status_id deficiency_report_category_id responsible_type responsible_id]
  has_associated_audits
  translation_class.class_eval do
    audited associated_with: :globalized_model,
            only: DeficiencyReport.translated_attribute_names

    def destroy
      run_callbacks :destroy
      true
    end
  end

  attr_accessor :officer_id, :officer_group_id

  belongs_to :category, class_name: "DeficiencyReport::Category", foreign_key: :deficiency_report_category_id
  belongs_to :status, class_name: "DeficiencyReport::Status", foreign_key: :deficiency_report_status_id
  belongs_to :author, -> { with_hidden }, class_name: "User", inverse_of: :deficiency_reports
  belongs_to :responsible, polymorphic: true
  has_many :comments, as: :commentable, inverse_of: :commentable, dependent: :destroy
  has_one :feedback_form, class_name: "DeficiencyReport::FeedbackForm", dependent: :destroy

  delegate :approximated_address, to: :map_location, allow_nil: true

  validates :deficiency_report_category_id, presence: true
  validates :author, presence: true
  validates :map_location, presence: true, on: :create, if: :map_location_required?

  # validates :terms_of_service, acceptance: { allow_nil: false }, on: :create #custom
  validates :resource_terms, acceptance: { allow_nil: false }, on: :create #custom

  validates_translation :title, presence: true

  before_save :calculate_hot_score

  scope :assigned, -> { where.not(responsible_type: nil, responsible_id: nil, assigned_at: nil) }
  scope :not_assigned, -> { where(responsible_type: nil).or(where(responsible_id: nil)) }

  scope :sort_by_most_commented,       -> { reorder(comments_count: :desc) }
  scope :sort_by_hot_score,            -> { reorder(hot_score: :desc) }
  scope :sort_by_newest,               -> { reorder(created_at: :desc) }
  scope :by_author, ->(user_id) {
    return if user_id.nil?

    where(author_id: user_id)
  }
  scope :admin_accepted, -> { Setting["deficiency_reports.admin_acceptance_required"].present? ? where(admin_accepted: true) : all }

  scope :closed, -> { joins(:status).where(deficiency_report_statuses: { archive_reports: true }) }
  scope :not_closed, -> { joins(:status).where(deficiency_report_statuses: { archive_reports: false }) }
  scope :archived, -> { where.not(archived_at: nil) }
  scope :not_archived, -> { where(archived_at: nil) }
  scope :closed_to_archive, -> { closed.not_archived.where("status_changed_at < ?", 7.days.ago) }

  pg_search_scope :pg_search,
    against: [:id, :on_behalf_of],
    associated_against: {
      translations: [:title, :description, :official_answer],
      author: :username
    },
    using: {
      trigram: {
        threshold: 0.03
      }
    },
    ignoring: :accents,
    ranked_by: ":trigram"

  pg_search_scope :address_search,
    associated_against: {
      map_location: :approximated_address
    },
    using: {
      trigram: {
        threshold: 0.08
      }
    },
    ignoring: :accents

  def audited_changes(**options)
    ch_attrs = {}

    if super.has_key?("deficiency_report_status_id")
      old_status_title = DeficiencyReport::Status.find_by(id: deficiency_report_status_id_was)&.title
      ch_attrs["deficiency_report_status_id"] = [old_status_title, status&.title]
    end

    if super.has_key?("deficiency_report_category_id")
      old_category_name = DeficiencyReport::Category.find_by(id: deficiency_report_category_id_was)&.name
      ch_attrs["deficiency_report_category_id"] = [old_category_name, category&.name]
    end

    if super.has_key?("responsible_type") || super.has_key?("responsible_id")
      if responsible_type_was.present?
        old_responsible_name = responsible_type_was.constantize.find_by(id: responsible_id_was)&.name
      else
        old_responsible_name = ""
      end
      ch_attrs["responsible"] = [old_responsible_name, responsible&.name]
    end

    super.except(
      "responsible_type", "responsible_id"
    ).merge!(ch_attrs)
  end

  def self.search(terms)
    pg_search(terms)
  end

  def self.archive_closed
    closed_to_archive.update_all(archived_at: Time.zone.now)
  end

  def searchable_values
    {
      id.to_s               => "A",
      author&.username      => "B",
      tag_list.join(" ")    => "B"
    }.merge!(searchable_globalized_values)
  end

  def searchable_translations_definitions
    { title       => "A",
      description => "D" }
  end

  def to_param
    "#{id}-#{title}".parameterize
  end

  def code
    "CONSUL-DF-#{created_at.strftime("%Y-%m")}-#{id}"
  end

  def publicly_visible?
    return false if hidden?

    Setting["deficiency_reports.admin_acceptance_required"].blank? || admin_accepted?
  end

  def total_votes
    cached_votes_total
  end

  def likes
    cached_votes_up
  end

  def dislikes
    cached_votes_down
  end

  def votes_score
    cached_votes_score
  end

  def votable_by?(user)
    user.present?
  end

  def self.deficiency_report_orders
    orders = %w[hot_score newest most_commented]
    orders.delete("hot_score") unless Setting["deficiency_reports.allow_voting"]
    orders
  end

  def register_vote(user, vote_value)
    if votable_by?(user)
      vote_by(voter: user, vote: vote_value)
    end
  end

  def calculate_hot_score
    self.hot_score = ScoreCalculator.hot_score(self)
  end

  def comments_allowed?(user)
    true
  end

  def responsible_officers
    case responsible
    when DeficiencyReport::Officer
      [responsible]
    when DeficiencyReport::OfficerGroup
      responsible.officers
    else
      []
    end
  end

  def archived?
    self.class.archived.exists?(id: id)
  end

  def section_tracking_section
    "deficiency_reports"
  end

  def section_tracking_user
    author
  end

  def assign_default_responsible
    default_responsible = district&.default_deficiency_report_responsible || category&.default_responsible

    if default_responsible.present?
      update_columns(
        responsible_type: default_responsible.class.name,
        responsible_id: default_responsible.id,
        assigned_at: Time.zone.now
      )
    end
  end

  def map_location_required?
    setting = Setting["deficiency_reports.map_location_required"]
    setting.nil? || setting.present?
  end
end
