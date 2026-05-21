class RecipientGroupFilter < ApplicationRecord
  KINDS = %w[
    newsletter_subscribers role
    phase_authors phase_subscribers comment_authors voting_participants
    geozone plz age_range gender
    individual_group manual_users
  ].freeze

  OPERATORS = %w[include exclude intersect].freeze

  REQUIRED_PARAMS = {
    "newsletter_subscribers" => [],
    "role"                   => ["role"],
    "phase_authors"          => ["projekt_phase_id"],
    "phase_subscribers"      => [], # validated below — either projekt_id OR projekt_phase_id
    "comment_authors"        => [],
    "voting_participants"    => ["projekt_phase_id"],
    "geozone"                => ["geozone_ids"],
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

      is_first =
        recipient_group.filters.where.not(id: id).none? ||
          recipient_group.filters.where.not(id: id).minimum(:position).to_i >= position.to_i

      errors.add(:operator, :must_be_include_for_first_filter) if is_first
    end

    def params_valid_for_kind
      return if kind.blank?

      required = REQUIRED_PARAMS[kind] || []
      required.each do |key|
        value = params&.dig(key)
        if value.blank? || (value.is_a?(Array) && value.empty?)
          errors.add(:params, "missing required key: #{key}")
        end
      end

      case kind
      when "role"
        errors.add(:params, "unsupported role") unless ALLOWED_ROLES.include?(params&.dig("role").to_s)
      when "phase_subscribers"
        unless params&.dig("projekt_id").present? || params&.dig("projekt_phase_id").present?
          errors.add(:params, "either projekt_id or projekt_phase_id required")
        end
      when "age_range"
        unless params&.dig("age_range_id").present? || params&.dig("min_age").present? || params&.dig("max_age").present?
          errors.add(:params, "either age_range_id or min/max required")
        end
      end
    end
end
