class Adm::SiteCustomization::EmailTemplatePolicy < ApplicationPolicy
  include Adm::Projekts::PermissionCheck

  def index?
    allowed?
  end

  def edit?
    allowed?
  end

  def update?
    allowed?
  end

  private

    def allowed?
      global_template? ? @user&.administrator? : permitted?
    end

    def projekt_from_record
      @record.is_a?(Class) ? nil : @record.projekt_phase&.projekt
    end

    def global_template?
      @record.is_a?(Class) || @record.projekt_phase.nil?
    end
end
