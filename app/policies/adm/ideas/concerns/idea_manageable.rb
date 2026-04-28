module Adm::Ideas::Concerns::IdeaManageable
  extend ActiveSupport::Concern

  private

    def idea_manager?
      @user&.administrator? || @user&.idea_manager? || officer_with_manage_all?
    end

    def officer_with_manage_all?
      @user&.idea_officer? && @user.idea_officer.manage_all?
    end
end
