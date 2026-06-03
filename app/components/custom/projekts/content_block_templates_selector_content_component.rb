class Projekts::ContentBlockTemplatesSelectorContentComponent < ApplicationComponent
  def initialize(dt_templates_by_category: [], context: "projekt")
    @dt_templates_by_category = dt_templates_by_category
    @context = context
  end

  def dt_templates_by_category
    @dt_templates_by_category
  end

  def category_id(category)
    category["name"].to_s.parameterize
  end

  def newsletter_context?
    @context == "newsletter"
  end

  def newsletter_email_template_names
    Newsletters::ContentBlockTemplatesSelectorComponent::EMAIL_TEMPLATE_NAMES
  end

  def newsletter_email_template_dir
    Newsletters::ContentBlockTemplatesSelectorComponent::TEMPLATE_DIR
  end

  def global_content_blocks
    SavedContentBlock.global.for_context(@context).order(:created_at)
  end

  def user_content_blocks
    SavedContentBlock.for_user(helpers.current_user).for_context(@context).order(:created_at)
  end
end
