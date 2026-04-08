class Adm::SettingPolicy < ApplicationPolicy
  def update?
    @user&.administrator? || idea_setting_manager?
  end

  private

    def idea_setting_manager?
      @record.is_a?(Setting) && @record.key.start_with?("ideas.") && @user&.idea_manager?
    end
end
