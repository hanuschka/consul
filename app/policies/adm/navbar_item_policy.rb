class Adm::NavbarItemPolicy < ApplicationPolicy
  def create?
    @user&.administrator? || landing_page_manager_for_record?
  end

  def update?
    @user&.administrator? || landing_page_manager_for_record?
  end

  def destroy?
    @user&.administrator? || landing_page_manager_for_record?
  end

  private

  def landing_page_manager_for_record?
    return false if @record.landing_page_id.blank?

    @user&.landing_page_manager?(@record.landing_page)
  end
end
