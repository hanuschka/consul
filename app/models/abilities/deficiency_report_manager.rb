module Abilities
  class DeficiencyReportManager
    include CanCan::Ability

    def initialize(user)
      merge Abilities::DeficiencyReports::Officer.new(user)

      can [:manage], ::DeficiencyReport::Officer
      can [:manage], ::DeficiencyReport::Category
      can [:manage], ::DeficiencyReport::Status
      can [:manage], ::DeficiencyReport::Area
      can [:approve_official_answer], ::DeficiencyReport do |dr|
        Setting['deficiency_reports.admins_must_approve_officer_answer'].present? &&
          !dr.official_answer_approved? &&
          dr.official_answer.present?
      end

      can :manage, DeficiencyReport
    end
  end
end
