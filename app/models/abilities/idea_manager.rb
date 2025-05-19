module Abilities
  class IdeaManager
    include CanCan::Ability

    def initialize(user)
      # can [:manage], ::DeficiencyReport::Officer
      # can [:manage], ::DeficiencyReport::Category
      # can [:manage], ::DeficiencyReport::Status
      # can [:manage], ::DeficiencyReport::OfficialAnswerTemplate
      # can [:manage], ::DeficiencyReport::OfficerGroup
      can [:manage], ::Idea::Category
      can [:manage], Idea
    end
  end
end
