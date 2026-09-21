class MunicipalPlan::TopicAssignment < ApplicationRecord
  belongs_to :municipal_plan, inverse_of: :topic_assignments
  belongs_to :topic, class_name: "MunicipalPlan::Topic",
    foreign_key: :municipal_plan_topic_id, inverse_of: :topic_assignments

  validates :municipal_plan_topic_id, uniqueness: { scope: :municipal_plan_id }
end
