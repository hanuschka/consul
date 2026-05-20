class AiProposalFlow::CriteriaListComponent < ApplicationComponent
  def initialize(criteria:)
    @criteria = criteria
  end

  private

    attr_reader :criteria

    def hard_criteria
      @hard_criteria ||= criteria.select { |c| c.kind.to_s == "hard" }
    end

    def soft_criteria
      @soft_criteria ||= criteria.reject { |c| c.kind.to_s == "hard" }
    end
end
