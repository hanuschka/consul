class Adm::PollPolicy < ApplicationPolicy
  def update?
    @user&.administrator?
  end
end
