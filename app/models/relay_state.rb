class RelayState < ApplicationRecord
  validates :token, presence: true
end
