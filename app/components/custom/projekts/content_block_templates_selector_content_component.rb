class Projekts::ContentBlockTemplatesSelectorContentComponent < ApplicationComponent
  def initialize(dt_templates_by_category: [])
    @dt_templates_by_category = dt_templates_by_category
  end

  def dt_templates_by_category
    @dt_templates_by_category
  end

  def category_id(category)
    category["name"].to_s.parameterize
  end

  def global_content_blocks
    SavedContentBlock.global.order(:created_at)
  end

  def user_content_blocks
    SavedContentBlock.for_user(helpers.current_user).order(:created_at)
  end
end
