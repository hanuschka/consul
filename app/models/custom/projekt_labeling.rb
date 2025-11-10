class ProjektLabeling < ApplicationRecord
  belongs_to :projekt_label
  belongs_to :labelable, polymorphic: true

  validates :projekt_label_id, uniqueness: { scope: [:labelable_type, :labelable_id] }
end
