class Sidebar::CategoriesCardComponent < ApplicationComponent
  def initialize(categories:, **options)
    @categories = categories
    @options = options
  end

  def render?
    @categories.present? && helpers.extended_feature?("modulewide.enable_categories")
  end
end
