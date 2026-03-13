class Adm::ProposalPolicy < ApplicationPolicy
  include Adm::Projekts::PermissionCheck

  def show?
    permitted?
  end

  def update?
    permitted?
  end

  def hide?
    can_moderate_projekt?
  end

  def ignore_flag?
    can_moderate_projekt? && !@record.ignored_flag? && !@record.hidden?
  end

  def unhide?
    can_moderate_projekt? && @record.hidden?
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end

  private

  def projekt_from_record
    @record.projekt
  end

  def can_moderate_projekt?
    @user&.has_pm_permission_to?("moderate", projekt_from_record)
  end
end
