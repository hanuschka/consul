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

  validate :first_filter_must_be_include

  private

    def first_filter_must_be_include
      return if operator == "include"
      return if recipient_group.blank?

      is_first =
        recipient_group.filters.where.not(id: id).none? ||
          recipient_group.filters.where.not(id: id).minimum(:position).to_i >= position.to_i

      errors.add(:operator, :must_be_include_for_first_filter) if is_first
    end
end
