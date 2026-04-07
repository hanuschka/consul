class Adm::SiteCustomization::EmailTemplatePolicy < ApplicationPolicy
  include Adm::Projekts::PermissionCheck

  def index?
    permitted?
  end

  def edit?
    permitted?
  end

  def update?
    permitted?
  end

  private

    def projekt_from_record
      @record.is_a?(Class) ? nil : @record.projekt_phase&.projekt
    end
end
