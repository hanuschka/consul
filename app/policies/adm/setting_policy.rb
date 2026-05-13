class Adm::SettingPolicy < ApplicationPolicy
  def update?
    return false unless @record.is_a?(Setting)
    return true if @user&.administrator?

    predicate = Adm::Section::MANAGER_PREDICATES[section_from_key]
    predicate.present? && @user&.public_send(predicate)
  end

  private

    def section_from_key
      parts = @record.key.to_s.split(".")
      parts[0] == "adm" ? parts[1] : parts[0]
    end
end
