class Adm::ImagePolicy < ApplicationPolicy
  def update?
    @user&.administrator?
  end
end
