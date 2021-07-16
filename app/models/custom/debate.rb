require_dependency Rails.root.join("app", "models", "debate").to_s

class Debate
  include Imageable
  include Search::Generic

  belongs_to :projekt, optional: true
  has_one :debate_phase, through: :projekt
  has_many :geozone_restrictions, through: :debate_phase
  has_many :geozone_affiliations, through: :projekt

  validates :projekt_id, presence: true, if: :require_a_projekt?

  def require_a_projekt?
    Setting["projekts.connected_resources"].present? ? true : false
  end

  def votable_by?(user)
    user &&
    !user.organization? &&
    user.level_two_or_three_verified? &&
    (
      Setting['feature.user.skip_verification'].present? ||
      projekt.blank? ||
      debate_phase && debate_phase.geozone_restrictions.blank? ||
      (debate_phase && debate_phase.geozone_restrictions.any? && debate_phase.geozone_restrictions.include?(user.geozone) )
    ) &&
    (
      projekt.blank? ||
      debate_phase && !debate_phase.expired?
    )

    #  user.voted_for?(self)
  end

  def elastic_searchable?
    hidden_at.nil?
  end

  def comments_allowed?(user)
    projekt.present? ? debate_phase.selectable_by?(user) : false
  end
end
