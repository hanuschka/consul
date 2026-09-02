module Budgets
  module Investments
    class VotesController < ApplicationController
      include FeatureFlags
      include GuestUsers
      #feature_flag :remove_investments_supports, only: :destroy

      # A page shows 24 cards; the cap only stops a hand-rolled request from asking us to
      # re-render every investment in the budget.
      MAX_REFRESHED_CARDS = 50

      load_and_authorize_resource :budget
      load_and_authorize_resource :investment, through: :budget, class: "Budget::Investment"
      load_and_authorize_resource through: :investment, through_association: :votes_for, only: :destroy

      def create
        @investment.register_selection(current_user, params[:vote_weight])

        prepare_cards_to_refresh

        respond_to do |format|
          format.html do
            redirect_to budget_investments_path(heading_id: @investment.heading.id),
              notice: t("flash.actions.create.support")
          end

          format.js { render :show }
        end
      end

      def destroy
        @investment.unliked_by(current_user)

        prepare_cards_to_refresh

        respond_to do |format|
          format.js { render :show }
        end
      end

      private

        # The support and withdraw buttons carry the ids of the cards that were on screen, so the
        # response can refresh all of them. Only the clicked card is re-rendered otherwise, and
        # crossing the phase's supports limit changes what every other card in the budget shows.
        #
        # Mirrors Budgets::Ballot::LinesController#load_investments, which solves the same
        # interdependency for ballot lines. Budgets without a supports limit keep re-rendering a
        # single card, as they did before the limit existed.
        #
        # Runs after the vote is written, never as a before_action: the answers being re-rendered
        # depend on it. All the cards reach the same ProjektPhase instance through the budget, so
        # resetting its cache once is enough for the whole response.
        def prepare_cards_to_refresh
          projekt_phase = @investment.budget.projekt_phase
          projekt_phase&.reset_permission_problem_cache!

          return if params[:investments_ids].blank?
          return unless projekt_phase&.supports_limit_applies?

          @investment_ids = Array(params[:investments_ids]).first(MAX_REFRESHED_CARDS)
          @investments = @investment.budget.investments
                                    .where(id: @investment_ids)
                                    .where.not(id: @investment.id)
                                    .includes(:votes_for)
        end
    end
  end
end
