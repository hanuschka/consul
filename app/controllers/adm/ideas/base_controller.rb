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
      raise Pundit::NotAuthorizedError unless current_user&.idea_manager? || current_user&.administrator?
    end

    def authenticate_user!
      redirect_to new_user_session_path unless current_user
    end
end
