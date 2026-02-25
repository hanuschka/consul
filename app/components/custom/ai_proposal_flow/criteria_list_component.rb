class AiProposalFlow::CriteriaListComponent < ApplicationComponent
  def initialize(criteria:)
    @criteria = criteria
  end

  private

    attr_reader :criteria
end
