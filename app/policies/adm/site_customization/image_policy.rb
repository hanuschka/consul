class Adm::SiteCustomization::ImagePolicy < ApplicationPolicy
  def update?
    @user&.administrator?
  end
end
