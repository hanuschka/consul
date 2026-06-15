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
      if deficiency_report_template?
        @user&.administrator? || @user&.deficiency_report_manager?
      elsif global_template?
        @user&.administrator?
      else
        manage_permitted?
      end
    end

    def deficiency_report_template?
      @record.respond_to?(:deficiency_report_template?) && @record.deficiency_report_template?
    end

    def projekt_from_record
      @record.is_a?(Class) ? nil : @record.projekt_phase&.projekt
    end

    def global_template?
      @record.is_a?(Class) || @record.projekt_phase.nil?
    end
end
