class Newsletters::MigrateBodyToContentBlocks < ApplicationService
  def initialize(newsletter)
    @newsletter = newsletter
  end

  def call
    return if @newsletter.sent_at.present?
    return if @newsletter.body.blank?
    return if @newsletter.content_blocks.exists?

    @newsletter.content_blocks.create!(
      name: "custom",
      body: @newsletter.body,
      key: "newsletter_content_block_#{@newsletter.id}_1_#{Time.current.to_i}",
      locale: "de"
    )
  end
end
