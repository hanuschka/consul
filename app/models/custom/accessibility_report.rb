class AccessibilityReport
  include ActiveModel::Model
  include ActiveModel::Attributes

  MAX_DESCRIPTION_LENGTH = 5000
  MAX_SHORT_TEXT_LENGTH = 500

  attribute :location, :string
  attribute :description, :string
  attribute :assistive_technology, :string
  attribute :email, :string

  validates :description, presence: true, length: { maximum: MAX_DESCRIPTION_LENGTH }
  validates :location, :assistive_technology, length: { maximum: MAX_SHORT_TEXT_LENGTH }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, length: { maximum: 255 }, allow_blank: true
end
