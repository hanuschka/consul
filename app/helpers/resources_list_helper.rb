# frozen_string_literal: true

module ResourcesListHelper
  def resources_list_item_component(resource, ids: nil, ballot: nil, voted_proposal_ids: nil)
    case resource
    when Projekt
      Projekts::ListItemComponent.new(projekt: resource)
    when Proposal
      Proposals::ListItemComponent.new(
        proposal: resource,
        voted: voted_proposal_ids && voted_proposal_ids.include?(resource.id)
      )
    when Debate
      Debates::ListItemComponent.new(debate: resource)
    when Poll
      Polls::ListItemComponent.new(poll: resource)
    when DeficiencyReport
      DeficiencyReports::ListItemComponent.new(deficiency_report: resource)
    when Budget::Investment
      Budgets::Investments::ListItemComponent.new(
        budget_investment: resource,
        budget_investment_ids: ids || [resource.id],
        ballot: ballot
      )
    when Idea
      Ideas::ListItemComponent.new(idea: resource)
    when Topic
      Topics::ListItemComponent.new(topic: resource)
    when ProjektEvent
      Projekts::ProjektEvents::ListItemComponent.new(projekt_event: resource)
    end
  end
end
