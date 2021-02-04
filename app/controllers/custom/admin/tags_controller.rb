class Admin::TagsController < Admin::BaseController
  before_action :find_tag, only: [:update, :destroy, :edit]

  respond_to :html, :js

  def index
    @tags = Tag.where(kind: ['category', 'subcategory']).order("kind ASC, name ASC").page(params[:page])
    @tag  = Tag.category.new
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
    Tag.find_or_create_by!(name: tag_params["name"]).update!(kind: kind)

    redirect_to admin_tags_path
  end

  def destroy
    @tag.destroy!
    redirect_to admin_tags_path
  end

  private

    def tag_params
      params.require(:tag).permit(:name, :kind)
    end

    def find_tag
      @tag = Tag.where(kind: ['category', 'subcategory']).find(params[:id])
    end
end