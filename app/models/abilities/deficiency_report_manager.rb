module Abilities
  class DeficiencyReportManager
    include CanCan::Ability

    def initialize(user)
      merge Abilities::DeficiencyReports::Officer.new(user)

      can [:manage], ::DeficiencyReport::Officer
      can [:manage], ::DeficiencyReport::Category
      can [:manage], ::DeficiencyReport::Status
      can [:manage], ::DeficiencyReport::OfficialAnswerTemplate
      can [:manage], ::DeficiencyReport::OfficerGroup
      can [:manage], DeficiencyReport

      can :get_coordinates_map_location, MapLocation
    end
  end
end
