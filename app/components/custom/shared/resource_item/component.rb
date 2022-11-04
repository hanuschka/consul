class Shared::ResourceItem::Component < ApplicationComponent
  renders_one :additional_body
  renders_one :first_footer_item
  renders_one :second_footer_item

  def initialize(tags: [], date:, title:, description:, image_url:, author: nil, wide_version: false)
    @title = title
    @description = description
    @image_url = image_url
    @tags = tags
    @date = date
    @author = author
    @wide_version = wide_version
  end
end
