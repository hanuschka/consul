class Adm::Moderation::SettingPolicy < ApplicationPolicy
  def show?
    @user&.administrator? || @user&.moderator?
  end
end
