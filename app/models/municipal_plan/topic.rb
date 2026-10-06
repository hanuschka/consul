class MunicipalPlan::Topic < ApplicationRecord
  translates :name, touch: true
  include Globalizable
  include MachineTranslatable

  has_many :topic_assignments, class_name: "MunicipalPlan::TopicAssignment",
    foreign_key: :municipal_plan_topic_id, dependent: :destroy, inverse_of: :topic
  has_many :municipal_plans, through: :topic_assignments

  validates_translation :name, presence: true

  default_scope { order(given_order: :asc) }

  before_destroy :ensure_not_in_use, prepend: true

  def safe_to_destroy?
    !municipal_plans.exists?
  end

  def self.order_topics(ordered_array)
    ordered_array.each_with_index do |topic_id, order|
      find(topic_id).update_column(:given_order, order + 1)
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
