class Adm::Officing::BasePolicy < ApplicationPolicy
  def officing_desk?
    officing_manager_or_admin?
  end

  def verify_user?
    officing_manager_or_admin?
  end

  def do_verify_user?
    officing_manager_or_admin?
  end

  def show?
    officing_manager_or_admin?
  end

  def index?
    officing_manager_or_admin?
  end

  def create?
    officing_manager_or_admin?
  end

  def destroy?
    officing_manager_or_admin?
  end

  private

    def officing_manager_or_admin?
      @user&.officing_manager? || @user&.administrator?
    end
end
