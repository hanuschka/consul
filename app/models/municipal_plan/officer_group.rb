class MunicipalPlan::OfficerGroup < ApplicationRecord
  has_many :officer_group_assignments, class_name: "MunicipalPlan::OfficerGroupAssignment",
    foreign_key: :municipal_plan_officer_group_id, dependent: :destroy, inverse_of: :officer_group
  has_many :officers, through: :officer_group_assignments
  has_many :municipal_plans, as: :responsible, inverse_of: false, dependent: :restrict_with_error

  validates :name, presence: true

  before_destroy :ensure_not_in_use, prepend: true

  def safe_to_destroy?
    !municipal_plans.exists?
  end

  private

    def ensure_not_in_use
      return if safe_to_destroy?

      errors.add(:base, I18n.t("activerecord.errors.messages.restrict_dependent_destroy.has_many",
                               record: MunicipalPlan.model_name.human(count: 2)))
      throw :abort
    end
end
