class Adm::SiteCustomization::VideoPolicy < ApplicationPolicy
  def update?
    @user&.administrator?
  end
end
