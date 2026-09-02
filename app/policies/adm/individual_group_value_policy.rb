class Adm::IndividualGroupValuePolicy < ApplicationPolicy
  def show?
    @user&.administrator?
  end

  def create?
    @user&.administrator?
  end

  def update?
    @user&.administrator?
  end

  def destroy?
    @user&.administrator?
  end

  def search_user?
    @user&.administrator?
  end

  def add_user?
    @user&.administrator?
  end

  def add_email?
    @user&.administrator?
  end

  def add_from_csv?
    @user&.administrator?
  end

  def remove_user?
    @user&.administrator?
  end

  def remove_email_from_auto_join_emails?
    @user&.administrator?
  end
end
