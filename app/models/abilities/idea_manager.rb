module Abilities
  class IdeaManager
    include CanCan::Ability

    def initialize(user)
      can [:manage], ::Idea::Officer
      can [:manage], ::Idea::Category
      can [:manage], Idea
    end
  end
end
