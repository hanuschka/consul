class Newsletters::ContentBlockTemplatesSelectorComponent < ApplicationComponent
  EMAIL_TEMPLATE_NAMES = %w[
    text
    heading
    text_with_heading
    image
    button
    divider
  ].freeze

  TEMPLATE_DIR = "newsletters/content_block_templates".freeze

  def email_template_names
    EMAIL_TEMPLATE_NAMES
  end

  def template_dir
    TEMPLATE_DIR
  end

  def global_content_blocks
    SavedContentBlock.global.for_context("newsletter").order(:created_at)
  end

  def user_content_blocks
    SavedContentBlock.for_user(helpers.current_user).for_context("newsletter").order(:created_at)
  end
end
