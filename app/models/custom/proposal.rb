require_dependency Rails.root.join("app", "models", "proposal").to_s
class Proposal < ApplicationRecord

  _validators.reject! { |attribute, _| attribute == :responsible_name }

  has_and_belongs_to_many :projekts

  validates :projekts, presence: true, if: :require_a_projekt?
  validate :description_sanitized

  def require_a_projekt?
    Setting["projekts.connected_resources"].present? ? true : false
  end

  def register_vote(user, vote_value)
    if !archived?
      vote_by(voter: user, vote: vote_value)
    end
  end

  def description_sanitized
    sanitized_description = ActionController::Base.helpers.strip_tags(description).strip
    errors.add(:description, :too_long, message: 'too long text', limit: Setting[ "max_proposal_description_length"]) if
      sanitized_description.length > Setting[ "max_proposal_description_length"].to_i
  end

  protected

  def set_responsible_name
      self.responsible_name = author.name + '_verified'
  end
end
