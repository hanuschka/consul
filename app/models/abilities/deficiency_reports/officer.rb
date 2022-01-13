module Abilities
  module DeficiencyReports
    class Officer
      include CanCan::Ability

      def initialize(user)
        merge Abilities::Common.new(user)
        dr_officer = user.deficiency_report_officer

        can [:update_official_answer], ::DeficiencyReport do |dr|
          if Setting['deficiency_reports.admins_must_assign_officer'].present?
            dr.officer == dr_officer && dr.official_answer_approved == false
          else
            dr.officer == dr_officer
          end
        end

        can [:update_status], ::DeficiencyReport do |dr|
          if Setting['deficiency_reports.admins_must_assign_officer'].present?
            dr.officer == dr_officer && dr.official_answer_approved == false
          else
            dr.officer == dr_officer
          end
        end
      end
    end
  end
end
