class AiProposalFlow::HeaderComponent < ApplicationComponent
  STEPS = [
    { n: 1, key: "idea",       icon: "fa-lightbulb" },
    { n: 2, key: "ai_draft",   icon: "fa-magic" },
    { n: 3, key: "evaluation", icon: "fa-chart-bar" },
    { n: 4, key: "submitted",  icon: "fa-paper-plane" }
  ].freeze

  def initialize(projekt_phase:, current_step:)
    @projekt_phase = projekt_phase
    @current_step = current_step
  end

  def steps
    available_steps = has_proposal_criteria? ? STEPS : STEPS.reject { |s| s[:n] == 3 }
    available_steps.each_with_index.map do |s, index|
      renumbered_n = index + 1
      state =
        if renumbered_n < @current_step then :completed
        elsif renumbered_n == @current_step then :active
        else :pending
        end
      s.merge(n: renumbered_n, state:)
    end
  end

  def projekt_page_url
    helpers.page_path(@projekt_phase.projekt.page.slug)
  end

  private

    def has_proposal_criteria?
      @projekt_phase.proposal_criteria.exists?
    end

    attr_reader :projekt_phase, :current_step
end
