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
    block = SiteCustomization::ContentBlock.custom_block_for(key, I18n.locale)
    if current_user.administrator?
      edit_link = link_to t("admin.action.edit"), edit_admin_site_customization_content_block_path(block, return_to: request.path )
    end
    res = block&.body
    res << edit_link ? "<br>#{edit_link}" : ""
    raw res
  end
end
