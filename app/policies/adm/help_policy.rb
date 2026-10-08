class Adm::HelpPolicy < ApplicationPolicy
  def show?
    return false if @user.blank?

    policy, method = Adm::SectionVisibility::SECTION_POLICIES.fetch(@record)

    policy.new(@user, nil).public_send(method)
  end
end
