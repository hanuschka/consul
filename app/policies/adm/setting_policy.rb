class Adm::SettingPolicy < ApplicationPolicy
  include Adm::Concerns::AreaManagerForSection

  def update?
    @user&.administrator? || idea_setting_manager? || adm_section_manager?
  end

  private

    def idea_setting_manager?
      @record.is_a?(Setting) && @record.key.start_with?("ideas.") && @user&.idea_manager?
    end

    def adm_section_manager?
      return false unless @record.is_a?(Setting) && @record.key.start_with?("adm.")

      area_manager_for?(@record.key.split(".")[1])
    end
end
