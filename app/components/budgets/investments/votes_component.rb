class Budgets::Investments::VotesComponent < ApplicationComponent
  attr_reader :investment, :investment_ids
  delegate :namespace, :current_user, :image_absolute_url, :link_to_verify_account, to: :helpers

  def initialize(investment, investment_ids: nil)
    @investment = investment
    @investment_ids = investment_ids
  end

  # The ids of the cards currently on screen travel with the support and withdraw requests as
  # hidden fields, so the response can refresh all of them instead of only the clicked one:
  # crossing the phase's supports limit changes what every other card in the budget shows.
  # Same mechanism the ballot buttons use.
  #
  # Only phases that actually have a limit send them - the response has nothing to do with them
  # otherwise, and they would be a hidden field per card on every budget list. An empty hash
  # renders no hidden fields at all.
  def refresh_params
    return {} unless investment.budget.projekt_phase&.supports_limit_applies?

    { investments_ids: Array(investment_ids) }
  end

  def support_path
    case namespace
    when "management"
      management_budget_investment_votes_path(investment.budget, investment)
    else
      budget_investment_votes_path(investment.budget, investment)
    end
  end

  def remove_support_path
    vote = investment.votes_for.find_by!(voter: current_user)

    case namespace
    when "management"
      management_budget_investment_vote_path(investment.budget, investment, vote)
    else
      budget_investment_vote_path(investment.budget, investment, vote)
    end
  end

  private

    def reason
      @reason ||= investment.reason_for_not_being_selectable_by(current_user)
    end

    def voting_allowed?
      reason != :not_voting_allowed
    end

    def user_voted_for?
      @user_voted_for = current_user&.voted_for?(investment) unless defined?(@user_voted_for)
      @user_voted_for
    end

    def display_support_alert?
      return false

      current_user &&
        !current_user.voted_in_group?(investment.group) &&
        investment.group.headings.count > investment.group.max_votable_headings
    end

    def confirm_vote_message
      t("budgets.investments.votes.confirm_group", count: investment.group.max_votable_headings)
    end

    def support_aria_label
      t("budgets.investments.votes.support_label", investment: investment.title)
    end

    def remove_support_aria_label
      t("budgets.investments.votes.remove_support_label", investment: investment.title)
    end

    def cannot_vote_text
      if reason.present? && !user_voted_for?
        t("votes.budget_investments.#{reason}",
          count: investment.group.max_votable_headings,
          verify_account: link_to_verify_account,
          supported_headings: (current_user && current_user.headings_voted_within_group(investment.group).map(&:name).sort.to_sentence))
      end
    end
end
