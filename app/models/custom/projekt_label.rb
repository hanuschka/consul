class ProjektLabel < ApplicationRecord
  include Iconable

  translates :name, touch: true
  include Globalizable

  belongs_to :projekt_phase
  belongs_to :masterportal_collection, optional: true
  has_many :projekt_labelings, dependent: :destroy

  scope :collection_backed, -> { where.not(masterportal_collection_id: nil) }
  scope :manual, -> { where(masterportal_collection_id: nil) }

  default_scope { order(:id) }

  def collection_backed?
    masterportal_collection_id.present?
  end

  def image_icon_url
    masterportal_collection&.encoded_icon_url
  end
end
