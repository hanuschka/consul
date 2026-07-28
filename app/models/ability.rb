class Ability
  include CanCan::Ability

  def initialize(user)
    if user # logged-in users
      can :use, :voice_assistant

      merge Abilities::Valuator.new(user) if user.valuator?
      merge Abilities::ProjektManager.new(user) if user.projekt_manager? && !user.administrator?
      merge Abilities::DeficiencyReportManager.new(user) if user.deficiency_report_manager?
      merge Abilities::IdeaManager.new(user) if user.idea_manager?

      if user.administrator?
        merge Abilities::Administrator.new(user)
      elsif user.deficiency_report_officer?
        merge Abilities::DeficiencyReports::Officer.new(user)
      elsif user.moderator?
        merge Abilities::Moderator.new(user)
      elsif user.manager?
        merge Abilities::Manager.new(user)
      elsif user.sdg_manager?
        merge Abilities::SDG::Manager.new(user)
      elsif user.guest?
        merge Abilities::Everyone.new(user)
      else
        merge Abilities::Common.new(user)
      end
    else
      merge Abilities::Everyone.new(user)
    end

    alias_action :wizard_step, to: :read
  end
end
