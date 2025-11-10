class DeficiencyReport::FeedbackForm < ApplicationRecord
  belongs_to :deficiency_report

  validates :overall_satisfaction, presence: true
end
