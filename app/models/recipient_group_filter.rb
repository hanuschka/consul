class RecipientGroupFilter < ApplicationRecord
  KINDS = %w[
    newsletter_subscribers role
    phase_authors phase_subscribers comment_authors voting_participants
    geozone plz age_range gender
    individual_group manual_users
  ].freeze

  OPERATORS = %w[include exclude intersect].freeze

  belongs_to :recipient_group

  acts_as_list scope: :recipient_group

  validates :kind, inclusion: { in: KINDS }
  validates :operator, inclusion: { in: OPERATORS }
end
