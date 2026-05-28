class RecipientGroupFilter < ApplicationRecord
  KINDS = %w[
    newsletter_subscribers role
    phase_authors phase_subscribers projekt_subscribers comment_authors voting_participants
    district plz age_range gender
    individual_group manual_users
  ].freeze

  OPERATORS = %w[include exclude intersect].freeze

  REQUIRED_PARAMS = {
    "newsletter_subscribers" => [],
    "role"                   => ["role"],
    "phase_authors"          => ["projekt_phase_id"],
    "phase_subscribers"      => [], # validated below — either projekt_id OR projekt_phase_id
    "projekt_subscribers"    => ["projekt_id"],
    "comment_authors"        => [],
    "voting_participants"    => ["projekt_phase_id"],
    "district"               => ["district_ids"],
    "plz"                    => ["plz_list"],
    "age_range"              => [], # validated below — either age_range_id OR min/max
    "gender"                 => ["gender"],
    "individual_group"       => ["individual_group_value_ids"],
    "manual_users"           => ["user_ids"]
  }.freeze

  ALLOWED_ROLES = %w[
    administrator moderator valuator
    projekt_manager idea_manager officing_manager deficiency_report_manager
  ].freeze

  belongs_to :recipient_group

  acts_as_list scope: :recipient_group

  validates :kind, inclusion: { in: KINDS }
  validates :operator, inclusion: { in: OPERATORS }
  validate :first_filter_must_be_include
  validate :params_valid_for_kind

  private

    def first_filter_must_be_include
      return if operator == "include"
      return if recipient_group.blank?
      return if recipient_group.filters.where.not(id: id).exists?

      errors.add(:operator, :must_be_include_for_first_filter)
    end

    # Required-key checks intentionally omitted: the UI mutates kind and params
    # in separate Turbo PATCHes, so an interim state where a new kind has no
    # params yet is normal. Resolvers tolerate blank params (return []).
    def params_valid_for_kind
      return if kind.blank?

      case kind
      when "role"
        role_value = params&.dig("role")
        if role_value.present? && !ALLOWED_ROLES.include?(role_value.to_s)
          errors.add(:params, "unsupported role")
        end
      end
    end
end
