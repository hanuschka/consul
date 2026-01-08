module Adm
  class RoleAssignmentsController < Adm::BaseController
    ROLE_MAP = {
      "administrator" => Administrator,
      "projekt_manager" => ProjektManager,
      "deficiency_report_manager" => DeficiencyReportManager,
      "idea_manager" => IdeaManager,
      "moderator" => Moderator,
      "valuator" => Valuator
    }.freeze

    def create
      role_class = role_class_from_param
      authorize [:adm, role_class], :index?

      @user = User.find(params[:user_id])
      role_class.find_or_create_by!(user: @user)
    end

    def destroy
      role_class = role_class_from_param
      authorize [:adm, role_class], :index?

      @user = User.find(params[:user_id])
      role_class.find_by!(user: @user)&.destroy!
    end

    private

      def role_class_from_param
        ROLE_MAP.fetch(params[:role]) do
          raise ActionController::BadRequest, "Invalid role parameter"
        end
      end
  end
end
