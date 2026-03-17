module Adm
  class RoleAssignmentsController < Adm::BaseController
    ROLE_MAP = {
      "administrator" => Administrator,
      "projekt_manager" => ProjektManager,
      "deficiency_report_manager" => DeficiencyReportManager,
      "idea_manager" => IdeaManager,
      "moderator" => Moderator,
      "valuator" => Valuator,
      "landing_page_manager" => LandingPageManager
    }.freeze

    def create
      role_class = role_class_from_param
      authorize role_class, :create?, policy_class: policy_class_for(role_class)

      @user = User.find(params[:user_id])
      role_class.find_or_create_by!(user: @user)
    end

    def destroy
      role_class = role_class_from_param
      authorize role_class, :destroy?, policy_class: policy_class_for(role_class)

      @user = User.find(params[:user_id])
      role_class.find_by!(user: @user)&.destroy!
    end

    def create_pending
      role_class = role_class_from_param
      authorize role_class, :index?, policy_class: policy_class_for(role_class)

      @pending = PendingRoleAssignment.new(
        email: params[:email],
        role_type: role_class.name,
        created_by_id: current_user.id
      )

      if @pending.save
        Mailer.pending_role_invite(@pending).deliver_later
        flash[:notice] = t("adm.pending_role_assignments.created", email: @pending.email)
      else
        flash[:alert] = @pending.errors.full_messages.join(", ")
      end

      redirect_back(fallback_location: adm_root_path)
    end

    def destroy_pending
      role_class = role_class_from_param
      authorize role_class, :index?, policy_class: policy_class_for(role_class)

      @pending = PendingRoleAssignment.find(params[:pending_id])
      @pending.destroy!
    end

    private

      def role_class_from_param
        ROLE_MAP.fetch(params[:role]) do
          raise ActionController::BadRequest, "Invalid role parameter"
        end
      end

      def policy_class_for(role_class)
        case role_class.name
        when "ProjektManager"
          Adm::Projekts::ProjektManagerPolicy
        when "LandingPageManager"
          Adm::LandingPages::LandingPageManagerPolicy
        else
          "Adm::#{role_class.name}Policy".constantize
        end
      end
  end
end
