require_dependency Rails.root.join("app", "models", "proposal").to_s
class Proposal < ApplicationRecord
  include Search::Generic
  include Labelable
  include Sentimentable
  include ResourceBelongsToProjekt
  include OnBehalfOfSubmittable
  include Memoable
  include ConditionallyVotable

  belongs_to :old_projekt, class_name: "Projekt", foreign_key: :projekt_id # TODO: remove column after data migration con1538

  delegate :projekt, to: :projekt_phase, allow_nil: true
  belongs_to :projekt_phase
  belongs_to :masterportal_pin, optional: true
  has_many :geozone_restrictions, through: :projekt_phase
  has_many :geozone_affiliations, through: :projekt_phase
  has_many :registered_address_district_affiliations, through: :projekt_phase

  delegate :votable_by?, to: :projekt_phase
  delegate :comments_allowed?, to: :projekt_phase

  validates_translation :description, presence: true
  validates :projekt_phase, presence: true
  validate :description_sanitized

  # validates :terms_of_service, acceptance: { allow_nil: false }, on: :create
  validates :resource_terms, acceptance: { allow_nil: false }, on: :create #custom

  scope :admin_accepted, -> { where(admin_accepted: true) }
  scope :masterportal_linked, -> { where.not(masterportal_pin_id: nil) }
  scope :user_created, -> { where(masterportal_pin_id: nil) }
  scope :with_index_card_associations, -> {
    includes(
      :translations,
      :image,
      :sentiment,
      :tags,
      :community,
      :votes_for,
      :projekt_labels,
      author: [:organization, :image],
      projekt_phase: [
        :settings,
        :projekt_labels,
        :geozone_restrictions,
        { projekt: [:translations, { page: :translations }] }
      ]
    )
  }
  scope :with_min_supports, ->(min_supports) {
    if min_supports.to_i > 0
      where("proposals.cached_votes_up >= ?", min_supports.to_i)
    else
      all
    end
  }
  scope :meets_minimum_supports, -> {
    restricted = ProjektPhaseSetting
      .where(key: "option.resource.minimum_supports_to_show")
      .where.not(value: ["0", "", nil])
      .pluck(:projekt_phase_id, :value)

    if restricted.empty?
      all
    else
      restricted_phase_ids = restricted.map(&:first)
      conditions = restricted.map do |phase_id, val|
        sanitize_sql_array(
          ["(proposals.projekt_phase_id = ? AND proposals.cached_votes_up >= ?)", phase_id, val.to_i]
        )
      end

      where(
        sanitize_sql_array(["proposals.projekt_phase_id NOT IN (?)", restricted_phase_ids]) +
        " OR " + conditions.join(" OR ")
      )
    end
  }
  scope :base_selection, -> {
    published
      .not_archived
      .not_retired
      .admin_accepted
  }

  scope :with_current_projekt, -> { joins(projekt_phase: :projekt).merge(Projekt.current) }
  scope :by_author, ->(user_id) {
    return if user_id.nil?

    where(author_id: user_id)
  }

  scope :sort_by_alphabet, -> {
    with_translations(I18n.locale).
    select("proposals.*, LOWER(proposal_translations.title)").
    reorder("LOWER(proposal_translations.title) ASC, proposals.id ASC")
  }
  scope :sort_by_votes_up, -> { reorder(cached_votes_up: :desc, id: :desc) }
  scope :sort_by_hot_score, -> { reorder(hot_score: :desc, id: :desc) }
  scope :sort_by_created_at, -> { reorder(created_at: :desc, id: :desc) }

  scope :seen,                     -> { where.not(ignored_flag_at: nil) }
  scope :unseen,                   -> { where(ignored_flag_at: nil) }

  default_scope { where(draft: false) }
  scope :discard_draft,            -> { published }
  scope :discard_archived,         -> { not_archived }

  scope :for_public_render,        -> {
    includes(:tags)
      .discard_draft
      .discard_archived
      .not_retired
  }

  def sentiment_required?
    super && masterportal_pin_id.blank?
  end

  def self.proposals_orders(user = nil)
    orders = %w[hot_score created_at alphabet votes_up random]
    # orders << "recommendations" if Setting["feature.user.recommendations_on_proposals"] && user&.recommended_proposals
    orders
  end

  def self.scoped_projekt_ids_for_index(current_user)
    Projekt
      .visible_for(current_user)
      .show_in_sidebar_filter
      .joins(:proposal_phases)
      .merge(
        ProjektPhase::ProposalPhase.current.or(ProjektPhase::ProposalPhase.has_resources)
      ).select(:id)
  end

  # TODO: REFACTOR FOR NEW DESIGN
  def self.scoped_projekt_ids_for_footer(projekt)
    projekt.top_parent.all_children_projekts.unshift(projekt.top_parent).select do |projekt|
      ProjektSetting.find_by(projekt:, key: "projekt_feature.main.activate").value.present? &&
        projekt.all_children_projekts.unshift(projekt).any? do |p|
 p.proposal_phases.any?(&:current?) || p.proposals.base_selection.any? end
    end.pluck(:id)
  end

  # Batched equivalent of user.voted_up_for?(proposal), for rendering a list
  # without a query per row.
  def self.up_voted_ids_by(user, proposals)
    return Set.new if user.blank? || proposals.blank?

    user.votes
      .where(votable_type: "Proposal", votable_id: proposals.map(&:id),
             vote_flag: true, vote_scope: nil)
      .pluck(:votable_id)
      .to_set
  end

  def successful?
    cached_votes_up >= custom_votes_needed_for_success
  end

  def self.successful
    ids = Proposal
      .includes(projekt_phase: :settings)
      .select { |proposal| proposal.cached_votes_up >= proposal.custom_votes_needed_for_success }
      .pluck(:id)

    Proposal.where(id: ids)
  end

  def self.unsuccessful
    ids = Proposal
      .includes(projekt_phase: :settings)
      .select { |proposal| proposal.cached_votes_up < proposal.custom_votes_needed_for_success }
      .pluck(:id)

    Proposal.where(id: ids)
  end

  def elastic_searchable?
    hidden_at.nil? && published?
  end

  def custom_votes_needed_for_success
    return Proposal.votes_needed_for_success unless projekt_phase.present?

    projekt_phase.settings.find { |setting| setting.key == "option.resource.votes_for_proposal_success" }.value.to_i
  end

  def publish
    update!(published_at: Time.current)
    NotificationServices::NewProposalNotifier.new(id).call
    send_new_actions_notification_on_published
  end

  def editable_by?(user)
    return false unless user
    return false unless editable?
    return false unless projekt_phase.present? && projekt_phase.selectable_by?(user)
    return true if author_id == user.id

    author.official_level > 0 && (author.official_level == user.official_level)
  end

  def likes
    cached_votes_up
  end

  def dislikes
    cached_votes_down
  end

  def submitted_anonymously?
    projekt_phase.feature?("form.anonimize_authors")
  end

  def conditional_vote_confirmable_for?(user)
    !archived? && super
  end

  protected

    def set_responsible_name
      self.responsible_name = "unregistriered"
    end
end
