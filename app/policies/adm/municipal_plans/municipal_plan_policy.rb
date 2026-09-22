class Adm::MunicipalPlans::MunicipalPlanPolicy < ApplicationPolicy
  def self.officers_see_all?
    Setting["municipal_plans.officers_see_all"].present?
  end

  def index?
    administrator_or_officer?
  end

  def show?
    return true if @user&.administrator?
    return false unless @user&.municipal_plan_officer?
    return true if self.class.officers_see_all?

    assigned_officer?
  end

  def create?
    administrator_or_officer?
  end

  def new?
    create?
  end

  def update?
    return true if @user&.administrator?
    return false unless @user&.municipal_plan_officer?

    assigned_officer?
  end

  def edit?
    update?
  end

  def destroy?
    @user&.administrator?
  end

  # Handing a Vorhaben in is part of editing it; releasing it never is.
  def submit?
    update?
  end

  def archive?
    update?
  end

  def unarchive?
    update?
  end

  def release?
    @user&.administrator?
  end

  # Renumbering the list only makes sense for someone who sees all of it.
  def reorder?
    return true if @user&.administrator?
    return false unless @user&.municipal_plan_officer?

    self.class.officers_see_all?
  end

  class Scope < Scope
    def resolve
      return scope.all if user&.administrator?
      return scope.none unless user&.municipal_plan_officer?
      return scope.all if Adm::MunicipalPlans::MunicipalPlanPolicy.officers_see_all?

      scope.assigned_to_officer(user.municipal_plan_officer)
    end
  end

  private

    def administrator_or_officer?
      @user&.administrator? || @user&.municipal_plan_officer?
    end

    def assigned_officer?
      return false unless @record.is_a?(MunicipalPlan)

      officer = @user.municipal_plan_officer
      return true if @record.responsible == officer

      @record.responsible.is_a?(MunicipalPlan::OfficerGroup) &&
        @record.responsible.officers.exists?(id: officer.id)
    end
end
