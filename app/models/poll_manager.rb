class PollManager < ApplicationRecord
  belongs_to :user, touch: true
  delegate :name, :email, to: :user

  has_many :assignments, class_name: "PollManagerAssignment", dependent: :destroy
  has_many :polls, through: :assignments
end
