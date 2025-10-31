class Api::ContentBlocksController < Api::BaseController
  before_action :find_projekt, only: %i[index new create]
  before_action :find_content_block, only: [:show, :update, :destroy]

  def index
    check_read_access!
    content_blocks = @projekt.content_blocks.order(:position)

    serialized_content_blocks = ContentBlockSerializer.serialize_collection(content_blocks)

    render json: { data: { content_blocks: serialized_content_blocks } }
  end

  def show
    check_read_access!
    serialized_content_block = ContentBlockSerializer.new(@content_block).serialize

    render json: { data: { content_block: serialized_content_block } }
  end

  def create
    check_admin_access!
    content_block = @projekt.content_blocks.new(content_block_params)

    if content_block.save
      serialized_content_block = ContentBlockSerializer.new(content_block).serialize

      render json: { data: { content_block: serialized_content_block } }, status: 201
    else
      render json: { error: { messages: content_block.errors.full_messages } }, status: 422
    end
  end

  def update
    check_admin_access!
    if @content_block.update(content_block_params)
      serialized_content_block = ContentBlockSerializer.new(@content_block).serialize

      render json: { data: { content_block: serialized_content_block } }
    else
      render json: { error: { messages: @content_block.errors.full_messages } }, status: 422
    end
  end

  def destroy
    check_admin_access!
    if @content_block.destroy
      render json: { message: "Content block destroyed" }
    else
      render json: { error: { messages: @content_block.errors.messages } }, status: 422
    end
  end

  def reorder
    check_admin_access!
    if params[:ordered_ids].present?
      SiteCustomization::ContentBlock.sort(params[:ordered_ids])
      render json: { message: "Content blocks reordered successfully" }
    else
      render json: { error: { messages: ["ordered_ids parameter is required"] } }, status: 422
    end
  end

  private

  def content_block_params
    params.require(:content_block).permit(
      :name,
      :locale,
      :body,
      :key,
      :position
    )
  end

  def find_projekt
    @projekt = Projekt.find(params[:projekt_id])
  end

  def find_content_block
    @content_block = @projekt.content_blocks.find(params[:id])
  end
end

