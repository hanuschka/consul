class Adm::Officing::BasePolicy < ApplicationPolicy
  # Sichtbarkeit der Section (IconRail / Admin-Home-Bento) auch fuer Administratoren.
  # Mutating Actions (verify_user, vote-related, bulk_votes, ...) bleiben bewusst
  # officing_manager-only: sie greifen im Controller auf current_user.officing_manager
  # zu (Vote-Zuordnung in poll_answers.officing_manager_id, Phasen-Assignments). Ohne
  # OfficingManager-Datensatz wuerden diese Routes mit NoMethodError fehlschlagen und
  # Audit-Spuren der Wahlbearbeitung wuerden geschwaecht. Stimmen-Integritaet hat
  # hier Vorrang vor Symmetrie zu anderen Adm-Bereichen.
  def officing_desk?
    officing_manager?
  end

  def verify_user?
    officing_manager?
  end

  def do_verify_user?
    officing_manager?
  end

  def show?
    administrator? || officing_manager?
  end

  def index?
    administrator? || officing_manager?
  end

  def create?
    officing_manager?
  end

  def destroy?
    officing_manager?
  end

  def bulk_votes?
    officing_manager?
  end

  def update_bulk_votes?
    officing_manager?
  end

  def update_open_answer?
    officing_manager?
  end

  private

    def administrator?
      @user&.administrator?
    end

    def officing_manager?
      @user&.officing_manager?
    end
end
