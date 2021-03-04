class Projekt < ApplicationRecord
  has_many :children, class_name: 'Projekt', foreign_key: 'parent_id'
  belongs_to :parent, class_name: 'Projekt', optional: true
end
