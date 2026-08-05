class Adm::BrevoMemberSyncPolicy < ApplicationPolicy
  def show?
    @user&.administrator?
  end

  def create?
    show?
  end

  def log?
    show?
  end
end
