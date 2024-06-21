module Notifiable
  extend ActiveSupport::Concern

  def notifiable_title
    case self.class.name
    when "Proposal", "Debate", "Budget::Investment", "Poll", "ProjektEvent", "ProjektLivestream", "ProjektNotification", "Topic", "DeficiencyReport"
      title
    when "ProjektPhase::ArgumentPhase", "ProjektPhase::QuestionPhase", "ProjektPhase::MilestonePhase"
      projekt.title
    when "ProposalNotification"
      proposal.title
    when "Comment"
      commentable.title
    else
      title
    end
  end

  def notifiable_body
    body if attribute_names.include?("body")
  end

  def notifiable_available?
    case self.class.name
    when "ProposalNotification"
      check_availability(proposal)
    when "Comment"
      check_availability(commentable)
    else
      check_availability(self)
    end
  end

  def check_availability(resource)
    resource.present? &&
      !(resource.respond_to?(:hidden?) && resource.hidden?) &&
      !(resource.respond_to?(:retired?) && resource.retired?)
  end

  def linkable_resource
    is_a?(ProposalNotification) ? proposal : self
  end
end
