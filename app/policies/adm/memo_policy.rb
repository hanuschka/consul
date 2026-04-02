class Adm::MemoPolicy < ApplicationPolicy
  def create?
    memoable_policy.update?
  end

  def destroy?
    @record.user_id == @user&.id
  end

  def send_notification?
    @record.user_id == @user&.id
  end

  private

    def memoable_policy
      memoable = @record.root_memoable

      case memoable
      when DeficiencyReport
        Adm::DeficiencyReports::DeficiencyReportPolicy.new(@user, memoable)
      when Idea
        Adm::Ideas::IdeaPolicy.new(@user, memoable)
      when Budget::Investment
        Adm::Projekts::BudgetPolicy.new(@user, memoable)
      else
        OpenStruct.new(update?: false)
      end
    end
end
