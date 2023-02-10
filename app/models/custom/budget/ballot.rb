require_dependency Rails.root.join("app", "models", "budget", "ballot").to_s

class Budget
  class Ballot < ApplicationRecord
    delegate :amount_available, :amount_available_info, :amount_progress, :amount_spent,
             :amount_spent_info, :amount_limit, :amount_limit_info, :change_vote_info,
             :enough_resources?, :formatted_amount_available, :formatted_amount_limit,
             :formatted_amount_spent, :not_enough_resources_error, :percentage_spent,
             :reason_for_not_being_ballotable, :voted_info, :change_vote_info_plain_text,
             to: :voting_style
  end
end
