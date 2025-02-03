class UserIndividualGroupValue < ApplicationRecord
  belongs_to :user
  belongs_to :individual_group_value

  validates :user_id, uniqueness: { scope: :individual_group_value_id }
end
