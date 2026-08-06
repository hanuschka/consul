class Ai::Tools::WhatsappAiAssistant::ListMyContributions < Ai::Tools::WhatsappAiAssistant::BaseTool
  MAX_PER_RESOURCE = 10

  description "Lists what this citizen has already submitted to the portal — their proposals and " \
              "their budget investments, newest first, with the link to each. Takes no arguments. " \
              "Use it to answer questions like what did I submit or where can I find my proposal."

  def execute
    { contributions: (proposals + investments).sort_by { |row| row[:submitted_on] }.reverse }
  end

  private

    def proposals
      ::Proposal
        .where(author: user)
        .includes(projekt_phase: { projekt: :page })
        .order(created_at: :desc)
        .limit(MAX_PER_RESOURCE)
        .map { |proposal| row_for(proposal, "proposal", proposal.projekt) }
    end

    def investments
      ::Budget::Investment
        .where(author: user)
        .includes(budget: { projekt_phase: { projekt: :page }})
        .order(created_at: :desc)
        .limit(MAX_PER_RESOURCE)
        .map { |investment| row_for(investment, "budget investment", investment.projekt) }
    end

    def row_for(resource, kind, projekt)
      {
        kind: kind,
        title: resource.title,
        projekt: projekt.present? ? projekt_title(projekt) : nil,
        submitted_on: resource.created_at.to_date.iso8601,
        url: ::Whatsapp::PublishedResourceUrl.call(resource)
      }.compact
    end
end
