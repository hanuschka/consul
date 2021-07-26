require_dependency Rails.root.join("app", "models", "debate").to_s

class Debate
  include Imageable

  belongs_to :projekt, optional: true
  has_one :debate_phase, through: :projekt
  has_many :geozone_restrictions, through: :debate_phase
  has_many :geozone_affiliations, through: :projekt

  validates :projekt_id, presence: true, if: :require_a_projekt?

  def require_a_projekt?
    Setting["projekts.connected_resources"].present? ? true : false
  end

  def votable_by?(user)
    return true if user && user.verified_organization?

    user &&
    !user.organization? &&
    user.level_three_verified? &&
    (
      projekt.blank? ||
      debate_phase && debate_phase.geozone_restricted == "no_restriction" ||
      debate_phase && debate_phase.geozone_restricted == "only_citizens" ||
      (debate_phase && debate_phase.geozone_restricted == "only_geozones" && debate_phase.geozone_restrictions.any? && debate_phase.geozone_restrictions.include?(user.geozone) )
    ) &&
    (
      projekt.blank? ||
      debate_phase && !debate_phase.expired?
    )

    #  user.voted_for?(self)
  end


end
