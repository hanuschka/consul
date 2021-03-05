class Admin::TagsController < Admin::BaseController
  before_action :find_tag, only: [:update, :destroy, :edit]

  respond_to :html, :js

  def index
    @tags = Tag.where(kind: ['category', 'subcategory', 'project']).order("kind ASC, name ASC").page(params[:page])
    @tag  = Tag.project.new
  end

  def update
    if @tag.update_attributes(tag_params)
      redirect_to admin_tags_path
    else
      render action: :edit
    end
  end

  def create
    kind = tag_params[:kind] ? tag_params[:kind] : 'category'
    Tag.find_or_create_by!(name: tag_params["name"], custom_logic_category_code: Tag.manage_categories, custom_logic_subcategory_code: Tag.manage_subcategories).update!(kind: kind)

    redirect_to admin_tags_path
  end

  def destroy
    @tag.destroy!
    redirect_to admin_tags_path
  end

  private

    def tag_params
      if params[:tag][:category_code]
        params[:tag][:custom_logic_category_code] = params[:tag][:category_code].reduce(0){|sum, i| sum += i.to_i}
      else
        params[:tag][:custom_logic_category_code] = 0
      end
      if params[:tag][:subcategory_code]
        params[:tag][:custom_logic_subcategory_code] = params[:tag][:subcategory_code].reduce(0){|sum, i| sum += i.to_i}
      else
        params[:tag][:custom_logic_subcategory_code] = 0
      end
      params.require(:tag).permit(:name, :kind, :custom_logic_category_code, :custom_logic_subcategory_code, :custom_logic_category_cloud, :custom_logic_subcategory_cloud, :custom_logic_usertags_cloud)
    end

    def find_tag
      @tag = Tag.where(kind: ['category', 'subcategory', 'project']).find(params[:id])
    end
end
