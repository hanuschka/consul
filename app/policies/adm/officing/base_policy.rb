class Adm::Officing::BasePolicy < ApplicationPolicy
  def officing_desk?
    officing_manager?
  end

  def verify_user?
    officing_manager?
  end

  def do_verify_user?
    officing_manager?
  end

  def show?
    officing_manager?
  end

  def index?
    officing_manager?
  end

  def create?
    officing_manager?
  end

  def destroy?
    officing_manager?
  end

  def bulk_votes?
    officing_manager?
  end

  def update_bulk_votes?
    officing_manager?
  end

  def update_open_answer?
    officing_manager?
  end

  private

    def officing_manager?
      @user&.officing_manager?
    end
end
