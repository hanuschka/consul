class Adm::ProposalPolicy < ApplicationPolicy
  include Adm::Projekts::PermissionCheck

  def show?
    manage_permitted? || moderate_permitted?
  end

  def update?
    manage_permitted?
  end

  def toggle_admin_accepted?
    manage_permitted? || moderate_permitted?
  end

  def hide?
    moderate_permitted?
  end

  def ignore_flag?
    moderate_permitted? && !@record.ignored_flag? && !@record.hidden?
  end

  def unhide?
    moderate_permitted? && @record.hidden?
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
end
