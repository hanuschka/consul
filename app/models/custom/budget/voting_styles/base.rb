require_dependency Rails.root.join("app", "models", "budget", "voting_styles", "base").to_s

class Budget::VotingStyles::Base
  def change_vote_info_plain_text
    I18n.t(
      "budgets.investments.index.sidebar.change_vote_info_plain.#{name}",
      phase_end_date: I18n.l(budget.current_phase.ends_at.to_date, format: :long)
    )
  end
end
