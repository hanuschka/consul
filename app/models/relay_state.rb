class RelayState < ApplicationRecord
  LIFETIME = 1.hour

  validates :token, presence: true

  scope :active, -> { where("created_at > ?", LIFETIME.ago) }
  scope :expired, -> { where("created_at <= ?", LIFETIME.ago) }
end
