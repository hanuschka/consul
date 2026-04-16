module Admin::PendingRoleAssignable
  extend ActiveSupport::Concern

  included do
    before_action :set_pending_assignments_for_index, only: [:index]
  end

  private

    def pending_role_type
      controller_name.classify
    end

    def set_pending_assignments_for_index
      @pending_role_assignments = PendingRoleAssignment.for_role_type(pending_role_type).order(created_at: :desc)
    end

    def check_pending_for_search
      searched_email = params[:search]&.strip
      return unless searched_email&.match?(URI::MailTo::EMAIL_REGEXP)
      return if User.exists?(email: searched_email.downcase)

      @pending_role_email = searched_email
      @pending_role_already_exists = PendingRoleAssignment.exists?(
        email: searched_email.downcase,
        role_type: params[:role]&.classify || pending_role_type
      )
    end
end
