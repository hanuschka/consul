class Adm::SiteCustomization::PagePolicy < ApplicationPolicy
  def update?
    @user&.administrator?
  end
end
