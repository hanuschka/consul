class Projekt < ApplicationRecord
  has_many :children, class_name: 'Projekt', foreign_key: 'parent_id'
  belongs_to :parent, class_name: 'Projekt', optional: true

  has_and_belongs_to_many :debates
  has_and_belongs_to_many :polls
  has_and_belongs_to_many :proposals
  has_and_belongs_to_many :budgets
end
