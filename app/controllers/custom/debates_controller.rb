  
require_dependency Rails.root.join("app", "controllers", "debates_controller").to_s

class DebatesController < ApplicationController

  before_action :load_categories, only: [:index, :new, :create, :edit, :map, :summary]

  def index_customization
    @featured_debates = @debates.featured
    take_only_by_tag_names
  end


  private

    def take_only_by_tag_names
      if params[:tags].present?
        @resources = @resources.tagged_with(params[:tags].split(","), all: true)
      end
    end
end