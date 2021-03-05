require_dependency Rails.root.join("app", "helpers", "content_blocks_helper").to_s
module ContentBlocksHelper

  def render_custom_block(key)
    block = SiteCustomization::ContentBlock.custom_block_for(key, I18n.locale)
    if current_user && current_user.administrator?
      edit_link = link_to t("admin.actions.edit"), edit_admin_site_customization_content_block_path(block, return_to: request.path )
    end
    res = block&.body || ""
    if current_user && current_user.administrator?
      res << edit_link ? "<br>#{edit_link}" : ""
    end
    raw res
  end
end
