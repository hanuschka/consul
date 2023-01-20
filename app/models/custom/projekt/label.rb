class Projekt::Label < ApplicationRecord
  include Iconable

  translates :name, touch: true
  include Globalizable

  belongs_to :projekt
end
