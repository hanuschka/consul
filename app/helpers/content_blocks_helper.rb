module ContentBlocksHelper
  def valid_blocks
    options = SiteCustomization::ContentBlock::VALID_BLOCKS.map do |key|
      [t("admin.site_customization.content_blocks.content_block.names.#{key}"), key]
    end
    Budget::Heading.allow_custom_content.each do |heading|
      options.push([heading.name, "hcb_#{heading.id}"])
    end
    options
  end

  def render_custom_block(key)
    raw SiteCustomization::ContentBlock.custom_block_for(key, I18n.locale)
  end
end
