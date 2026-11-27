load Rails.root.join("app", "models", "milestone.rb")

class Milestone < ApplicationRecord
include MachineTranslatable
  def self.order_by_publication_date(sorting_order = nil)
    sorting_order ||= :asc
    order(publication_date: sorting_order, created_at: :asc)
  end

  def projekt
    milestoneable.is_a?(Projekt) ? milestoneable : nil
  end
end
