require_dependency Rails.root.join("app", "controllers", "debates_controller").to_s

class DebatesController < ApplicationController

  before_action :load_categories, only: [:index, :new, :create, :edit, :map, :summary]
  before_action :process_tags, only: [:create, :update]

  def index_customization
    @featured_debates = @debates.featured
    take_only_by_tag_names
  end


  private

  def process_tags
    params[:debate][:tag_list_categories].split(",").each do |t|
      next if t.strip.blank?
      Tag.find_or_create_by name: t.strip, kind: :category
    end
    params[:debate][:tag_list_subcategories].split(",").each do |t|
      next if t.strip.blank?
      Tag.find_or_create_by name: t.strip, kind: :subcategory
    end
    params[:debate][:tag_list] ||= ""
    params[:debate][:tag_list] += ((params[:debate][:tag_list_categories] || "").split(",") + (params[:debate][:tag_list_subcategories] || "").split(",")).join(",")
    params[:debate][:tag_list_categories], params[:debate][:tag_list_subcategories] = nil, nil
  end

  def take_only_by_tag_names
    if params[:tags].present?
      @resources = @resources.tagged_with(params[:tags].split(","), all: true, any: :true)
      @subcategories = @resources.tag_counts.subcategory
    end
  end
end