class Adm::Newsletters::ContentBlockPolicy < ApplicationPolicy
  def create?
    editable?
  end

  def update?
    editable?
  end

  def destroy?
    editable?
  end

  def update_position?
    editable?
  end

  def change_with_ai?
    editable?
  end

  def generate_with_ai?
    editable?
  end

  def ai_generation_status?
    editable?
  end

  def cancel_ai_generation?
    editable?
  end

  private

    def editable?
      return false if @user.blank? || !@user.administrator?
      return false if @record.newsletter.blank?

      @record.newsletter.sent_at.nil?
    end
end
