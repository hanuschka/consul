class Api::ContentBlocksController < Api::BaseController
  before_action :find_projekt, only: %i[index]
  before_action :find_content_block, only: [:show]

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

  private

  def find_projekt
    @projekt = Projekt.find(params[:projekt_id])
  end

  def find_content_block
    @content_block = @projekt.content_blocks.find(params[:id])
  end
end

