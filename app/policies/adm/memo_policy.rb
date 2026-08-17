class Adm::MemoPolicy < ApplicationPolicy
  # Not update?: writing an internal note is a weaker act than changing the resource, and a
  # deficiency report officer who only holds the read-all visibility right is meant to be able to
  # leave notes on an Anliegen they cannot otherwise touch. Policies that do not answer add_memo?
  # keep the old behaviour through ApplicationPolicy#add_memo?.
  def create?
    memoable_policy.add_memo?
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
        OpenStruct.new(add_memo?: false)
      end
    end
end
