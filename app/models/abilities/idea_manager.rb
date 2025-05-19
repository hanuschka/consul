module Abilities
  class IdeaManager
    include CanCan::Ability

    def initialize(user)
      can [:manage], Idea
    end
  end
end
