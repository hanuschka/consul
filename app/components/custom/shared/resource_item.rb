class Shared::ResourceItem < ApplicationComponent
  renders_one :additional_body
  renders_one :first_footer_item
  renders_one :second_footer_item

  DATE_RANGE_FORMAT = "%d. %B %Y"
  DATE_FORMAT = "%d.%m.%Y"

  def initialize(
    resource: nil,
    projekt: nil,
    title:, description:, image_url:,
    resource_name: nil,
    author: nil, wide: false, id: nil,
    start_date: nil, end_date: nil, date: nil,
    url: nil, tags: [], sdgs: [],
    image_placeholder_icon_class: 'fa-file'
  )
    @resource = resource
    @title = title
    @projekt = projekt
    @description = description
    @image_url = image_url
    @author = author
    @wide = wide
    @url = url
    @start_date = start_date
    @end_date = end_date
    @date = date
    @tags = tags
    @sdgs = sdgs
    @resource_name = resource_name
    @image_placeholder_icon_class = image_placeholder_icon_class

    if @wide
      @sdgs = @sdgs.first(5)
    else
      @sdgs = @sdgs.first(4)
    end

    @id = id
  end

  def component_class_name
    if @wide
      '-wide'
    end
  end

  def days_left
    if @end_date.present?
      "Noch #{(@end_date - Date.today).to_i} Tage"
    end
  end

  def date
    @date&.strftime(DATE_FORMAT)
  end

  def date_range
    return if @start_date.blank? || @end_date.blank?

    "#{@start_date.strftime(DATE_RANGE_FORMAT)} - #{@end_date.strftime(DATE_RANGE_FORMAT)}"
  end

  def truncate_length
    if @wide
      150
    else
      120
    end
  end
end
