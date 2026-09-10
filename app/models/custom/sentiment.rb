class Sentiment < ApplicationRecord
  translates :name, touch: true
  include Globalizable
  include MachineTranslatable

  belongs_to :projekt_phase
  has_many :proposals, dependent: :nullify
  has_many :debates, dependent: :nullify

  default_scope { order(:id) }
end
