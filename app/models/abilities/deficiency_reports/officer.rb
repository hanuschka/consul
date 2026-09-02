module Abilities
  module DeficiencyReports
    class Officer
      include CanCan::Ability

      def initialize(user)
        merge Abilities::Common.new(user)
        dr_officer = user.deficiency_report_officer

        can :index, DeficiencyReport

        # Reading and note-taking are wider than editing: with the visibility setting on, any officer
        # may open any Anliegen, but reassigning it stays with whoever is responsible.
        can [:show, :add_memo, :audits], DeficiencyReport do |dr|
          if Setting["deficiency_reports.admins_must_assign_officer"].present?
            Setting["deficiency_reports.officers_see_all_reports"].present? ||
              dr_officer&.manage_all? ||
              dr.responsible == dr_officer ||
              dr.responsible.is_a?(DeficiencyReport::OfficerGroup) && dr.responsible.officers.include?(dr_officer)
          else
            true
          end
        end

        can [:edit, :update], DeficiencyReport do |dr|
          if Setting["deficiency_reports.admins_must_assign_officer"].present?
            dr_officer&.manage_all? ||
              dr.responsible == dr_officer ||
              (dr.responsible.is_a?(DeficiencyReport::OfficerGroup) &&
                dr.responsible.officers.include?(dr_officer))
          else
            true
          end
        end

        can :get_coordinates_map_location, MapLocation
        can :send_notification, Memo, user_id: user.id
      end
    end
  end
end
