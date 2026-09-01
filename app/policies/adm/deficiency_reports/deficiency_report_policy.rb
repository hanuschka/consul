class Adm::DeficiencyReports::DeficiencyReportPolicy < ApplicationPolicy
  include Adm::DeficiencyReports::Concerns::DeficiencyReportManageable
  def index?
    deficiency_report_manager_or_officer?
  end

  def new?
    deficiency_report_manager?
  end

  def create?
    deficiency_report_manager?
  end

  def show?
    deficiency_report_manager? || readable_by_officer?
  end

  def edit?
    deficiency_report_manager? || assigned_officer?
  end

  def update?
    deficiency_report_manager? || assigned_officer?
  end

  def destroy?
    deficiency_report_manager?
  end

  def audits?
    deficiency_report_manager? || readable_by_officer?
  end

  # Anyone who may read the Anliegen may annotate it — that is the whole point of granting read
  # access without the right to reassign.
  def add_memo?
    deficiency_report_manager? || readable_by_officer?
  end

  def toggle_watch?
    deficiency_report_manager? || readable_by_officer?
  end

  # Handing an Anliegen to a colleague is a reading-level act, not an editing one: it grants them the
  # same view you already have and does not change the Anliegen itself.
  def share?
    deficiency_report_manager? || readable_by_officer?
  end

  def unwatch?
    toggle_watch?
  end

  def accept?
    deficiency_report_manager?
  end

  def toggle_image?
    deficiency_report_manager?
  end

  def stats?
    deficiency_report_manager?
  end

  def settings?
    deficiency_report_manager?
  end

  def feedback_form?
    deficiency_report_manager? || readable_by_officer?
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end

  private

    def deficiency_report_manager_or_officer?
      deficiency_report_manager? || @user&.deficiency_report_officer?
    end

    # Reading is wider than editing: the visibility setting lets any officer open any Anliegen and
    # add internal notes, while reassigning it stays with whoever is actually responsible.
    #
    # Watching also grants reading, which is what makes sharing work with the visibility setting off:
    # sharing an Anliegen creates a watch for the recipient, and a recipient who could not open it
    # would have been shared nothing. Self-watching grants no new access, since the bell can only be
    # reached from an Anliegen the officer could already read.
    def readable_by_officer?
      return true if assigned_officer?
      return false unless @user&.deficiency_report_officer?
      return false unless @record.is_a?(DeficiencyReport)
      return true if @record.watched_by?(@user)

      Setting["deficiency_reports.officers_see_all_reports"].present?
    end

    def assigned_officer?
      return false unless @user&.deficiency_report_officer?
      return false unless @record.is_a?(DeficiencyReport)
      return true unless Setting["deficiency_reports.admins_must_assign_officer"].present?

      officer = @user.deficiency_report_officer
      return true if officer.manage_all?
      return true if @record.responsible == officer

      if @record.responsible.is_a?(DeficiencyReport::OfficerGroup)
        @record.responsible.officers.exists?(id: officer.id)
      else
        false
      end
    end
end
