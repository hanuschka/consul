module SavedContentBlockAdminActions
  extend ActiveSupport::Concern
  include Translatable

  included do
    before_action :find_saved_content_block, except: [:create]
  end

  def create
    @saved_content_block = SavedContentBlock.new(saved_content_block_params)

    if params[:saved_content_block][:user_specific].to_s == 'true'
      @saved_content_block.user = current_user
    end

    if @saved_content_block.save
      content_block_html =
        ApplicationController.render(
          SavedContentBlocks::ItemComponent.new(
            saved_content_block: @saved_content_block
          ),
          layout: false
        ).strip

      render json: {
        status: "created",
        saved_content_block_item_html: content_block_html
      }, status: 201
    else
      render json: { errors: @saved_content_block.errors.messages }, status: :unprocessable_entity
    end
  end

  def update
    if @saved_content_block.update(saved_content_block_params)
      render json: { status: "updated" }, status: 200
    else
      render json: { errors: @saved_content_block.errors.messages }, status: :unprocessable_entity
    end
  end

  def destroy
    if @saved_content_block.destroy
      render json: { status: "destroyed" }, status: 200
    else
      render json: { errors: @saved_content_block.errors.messages }, status: :unprocessable_entity
    end
  end

  private

  def find_saved_content_block
    @saved_content_block = SavedContentBlock.find(params[:id])
  end

  def saved_content_block_params
    params.require(:saved_content_block).permit(:name, :content)
  end
end
