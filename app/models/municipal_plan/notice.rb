class MunicipalPlan::Notice < ApplicationRecord
  belongs_to :municipal_plan, inverse_of: :notices

  MAX_BODY_LENGTH = 5000

  validates :email, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :email, length: { maximum: 255 }
  validates :name, length: { maximum: 100 }
  validates :body, presence: true
  validates :body, length: { maximum: MAX_BODY_LENGTH }
end
