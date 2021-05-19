require_dependency Rails.root.join("app", "models", "proposal").to_s
class Proposal < ApplicationRecord
  include Search::Generic

  belongs_to :projekt, optional: true
  has_one :proposal_phase, through: :projekt
  has_many :geozones, through: :proposal_phase

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
        proposal_phase && proposal_phase.geozones.blank? ||
        (proposal_phase && proposal_phase.geozones.any? && proposal_phase.geozones.include?(user.geozone) )
      ) &&
      proposal_phase && !proposal_phase.expired?
  end
end
