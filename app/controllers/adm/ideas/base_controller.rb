class Adm::Ideas::BaseController < Adm::BaseController
  before_action :authenticate_user!
  before_action :verify_idea_manager

  private

    def adm_header_title
      I18n.t("adm.ideas.title")
    end

    def adm_menu_component
      Adm::Ideas::MenuComponent.new
    end

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

      scope.where(officer: current_user.idea_officer)
    end
end
