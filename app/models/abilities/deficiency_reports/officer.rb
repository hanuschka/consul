module Abilities
  module DeficiencyReports
    class Officer
      include CanCan::Ability

      def initialize(user)
        merge Abilities::Common.new(user)
        dr_officer = user.deficiency_report_officer

        can [:index, :show, :edit, :update_category, :add_memo], DeficiencyReport,
          id: DeficiencyReport.where(officer: dr_officer).ids

        can [:update_official_answer], ::DeficiencyReport do |dr|
          if Setting["deficiency_reports.admins_must_approve_officer_answer"].present?
            dr.officer == dr_officer && dr.official_answer_approved == false
          elsif Setting["deficiency_reports.admins_must_assign_officer"].present?
            dr.officer == dr_officer
          else
            true
          end
        end

        can [:update_status], ::DeficiencyReport do |dr|
          if Setting["deficiency_reports.admins_must_approve_officer_answer"].present?
            dr.officer == dr_officer && dr.official_answer_approved == false
          elsif Setting["deficiency_reports.admins_must_assign_officer"].present?
            dr.officer == dr_officer
          else
            true
          end
        end

        can [:update_officer], ::DeficiencyReport do |dr|
          Setting["deficiency_reports.admins_must_assign_officer"].present? ? dr.officer == dr_officer : true
        end
      end
    end
  end
end
