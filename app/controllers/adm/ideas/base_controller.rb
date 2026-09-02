class Adm::Ideas::BaseController < Adm::BaseController
  before_action :authenticate_user!
  before_action :verify_idea_manager

  rescue_from Pundit::NotAuthorizedError do |exception|
    handle_not_authorized(exception, adm_ideas_root_path)
  end

  private

    def verify_idea_manager
      raise Pundit::NotAuthorizedError unless current_user&.idea_manager? ||
                                              current_user&.idea_officer? ||
                                              current_user&.administrator?
    end

    def authenticate_user!
      redirect_to new_user_session_path unless current_user
    end

    def scoped_ideas
      base = policy_scope(Idea, policy_scope_class: Adm::Ideas::IdeaPolicy::Scope)
      filter_assigned_ideas_only(base)
    end

    def filter_assigned_ideas_only(scope)
      return scope if current_user.administrator? || current_user.idea_manager?
      return scope unless Setting["ideas.admins_must_assign_officer"].present?
      return scope unless current_user.idea_officer?

      officer = current_user.idea_officer

      return scope if officer.manage_all?

      scope.where(officer: officer)
    end
end
