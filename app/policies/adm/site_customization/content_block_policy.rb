class Adm::SiteCustomization::ContentBlockPolicy < ApplicationPolicy
  def update?
    @user&.administrator?
  end
end
