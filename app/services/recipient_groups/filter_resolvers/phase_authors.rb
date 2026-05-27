module RecipientGroups
  module FilterResolvers
    class PhaseAuthors < Base
      BUDGET_CRITERIA = %w[feasible unfeasible selected winners not_winners].freeze

      def emails
        return [] if params[:projekt_phase_id].blank?

        phase = ProjektPhase.find_by(id: params[:projekt_phase_id])
        return [] unless phase

        user_ids = user_ids_for(phase)
        User.actual.where(id: user_ids).pluck(:email).compact.uniq
      end

      private

        def user_ids_for(phase)
          criterion = params[:criterion].to_s

          case phase.type
          when "ProjektPhase::BudgetPhase"
            return phase.budget.investments.pluck(:author_id).uniq if criterion == "all"
            return [] unless BUDGET_CRITERIA.include?(criterion)

            phase.send("authors_of_#{criterion}_ids")
          when "ProjektPhase::ProposalPhase"
            Proposal.where(projekt_phase_id: phase.id).pluck(:author_id)
          when "ProjektPhase::DebatePhase"
            Debate.where(projekt_phase_id: phase.id).pluck(:author_id)
          when "ProjektPhase::ArgumentPhase"
            phase.respond_to?(:arguments) ? phase.arguments.pluck(:author_id) : []
          when "ProjektPhase::QuestionPhase"
            phase.respond_to?(:projekt_questions) ? phase.projekt_questions.pluck(:author_id) : []
          else
            []
          end
        end
    end
  end
end
