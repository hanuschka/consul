class MapLayer < ApplicationRecord
  belongs_to :projekt

  enum protocol: { regular: 0, wms: 1 }

  def self.protocol_attributes_for_select
    protocols.map do |protocol, _|
      [protocol, I18n.t("activerecord.attributes.map_layer.protocols.#{protocol}")]
    end
  end
end
