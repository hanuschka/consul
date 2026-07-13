class Adm::SavedContentBlockPolicy < ApplicationPolicy
  def create?
    @user&.administrator?
  end

  def update?
    @user&.administrator?
  end

  def destroy?
    @user&.administrator?
  end
end
