class AwesomeIcon < ApplicationRecord
  validates :name, presence: true, uniqueness: true
  validates :unicode, presence: true, uniqueness: true
end
