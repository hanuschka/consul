# frozen_string_literal: true

class Resources::TableComponent < ApplicationComponent
  attr_reader :columns, :caption

  def initialize(columns:, caption:, region_label: nil)
    @columns = columns
    @caption = caption
    @region_label = region_label
  end

  def region_label
    @region_label.presence || caption
  end

  def caption_id
    @caption_id ||= "resources-table-caption-#{SecureRandom.hex(4)}"
  end
end
