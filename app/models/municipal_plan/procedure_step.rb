class MunicipalPlan::ProcedureStep < ApplicationRecord
  translates :name, touch: true
  include Globalizable
  include MachineTranslatable

  has_many :municipal_plans, class_name: "MunicipalPlan", foreign_key: :procedure_step_id,
    dependent: :restrict_with_error, inverse_of: :procedure_step

  validates_translation :name, presence: true

  default_scope { order(given_order: :asc, id: :asc) }

  before_destroy :ensure_not_in_use, prepend: true

  def safe_to_destroy?
    !municipal_plans.exists?
  end

  def self.order_procedure_steps(ordered_array)
    ordered_array.each_with_index do |procedure_step_id, order|
      find(procedure_step_id).update_column(:given_order, order + 1)
    end
  end

  private

    def ensure_not_in_use
      return if safe_to_destroy?

      errors.add(:base, I18n.t("activerecord.errors.messages.restrict_dependent_destroy.has_many",
                               record: MunicipalPlan.model_name.human(count: 2)))
      throw :abort
    end
end
