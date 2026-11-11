class Budget
  class Result
    Tie = Struct.new(:candidates, :free_places, :remaining_budget, keyword_init: true)
    Plan = Struct.new(:winners, :tie, keyword_init: true)

    attr_accessor :budget, :heading

    def initialize(budget, heading)
      @budget = budget
      @heading = heading
    end

    def calculate_winners
      @budget.with_lock do
        reset_winners
        Budget::Investment.where(id: plan.winners.map(&:id)).update_all(winner: true)
        @budget.update_columns(winners_calculated_at: Time.current, winners_tie_open: plan.tie.present?)
      end
    end

    def pending_tie
      calculated_at = @budget.winners_calculated_at
      resolved_at = @budget.tie_resolved_at
      return unless calculated_at && @budget.winners_tie_open
      return if resolved_at && resolved_at >= calculated_at

      plan.tie
    end

    def resolve_tie(investment_ids)
      ids = investment_ids.map(&:to_i).uniq

      @budget.with_lock do
        tie = pending_tie
        next false unless tie

        picked = tie.candidates.select { |investment| ids.include?(investment.id) }
        next false unless picked.size == ids.size
        next false if tie.free_places && picked.size > tie.free_places
        next false if tie.remaining_budget && picked.sum(&:price) > tie.remaining_budget

        calculate_winners
        Budget::Investment.where(id: picked.map(&:id)).update_all(winner: true)
        @budget.update_column(:tie_resolved_at, @budget.winners_calculated_at)
        true
      end
    end

    def investments
      if @budget.show_money?
        heading.investments.selected.where.not(price: nil).sort_by_ballots
      else
        heading.investments.selected.sort_by_ballots
      end
    end

    def score(investment)
      investment.ballot_lines_count
    end

    private

      def plan
        @plan ||= build_plan
      end

      def build_plan
        winners = []
        free_places = max_winners
        remaining_budget = heading.price if @budget.show_money?

        investments.compatible.to_a.chunk_while { |a, b| score(a) == score(b) }.each do |group|
          break if free_places&.zero?

          candidates = group.select { |investment| remaining_budget.nil? || investment.price <= remaining_budget }
          next if candidates.empty?

          places_fit = free_places.nil? || candidates.size <= free_places
          budget_fits = remaining_budget.nil? || candidates.sum(&:price) <= remaining_budget

          unless places_fit && budget_fits
            tie = Tie.new(candidates: candidates, free_places: free_places, remaining_budget: remaining_budget)
            return Plan.new(winners: winners, tie: tie)
          end

          winners.concat(candidates)
          free_places -= candidates.size if free_places
          remaining_budget -= candidates.sum(&:price) if remaining_budget
        end

        Plan.new(winners: winners, tie: nil)
      end

      def max_winners
        @budget.max_number_of_winners if @budget.max_number_of_winners&.positive?
      end

      def reset_winners
        Budget::Investment.with_hidden.where(heading_id: heading.id).update_all(winner: false)
      end
  end
end
