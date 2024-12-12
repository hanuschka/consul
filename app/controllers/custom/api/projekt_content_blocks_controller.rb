class Api::ProjektContentBlocksController < Api::BaseController
  before_action :find_projekt, only: [:create]
  before_action :find_content_block, only: [
    :destroy, :update, :update_position
  ]

  # Add authorization
  skip_authorization_check

  def create
    @content_block = @projekt.content_blocks.build(
      name: "custom",
      body: params[:html],
      key: "projekt_content_block_#{@projekt.id}_#{@projekt.content_blocks.count + 1}_#{DateTime.now.to_i}",
      locale: "de"
    )

    if @content_block.save
      if params[:previous_content_block_id].present?
        @previous_content_block = @projekt.content_blocks.find(params[:previous_content_block_id])
        @content_block.insert_at(@previous_content_block.position + 1)
      else
        @content_block.move_to_top
      end

      render json: { content_block: {id: @content_block.id}, status: { message: "Content block updated" }}
    else
      render json: { message: "Error updating content_block" }
    end
  end

  def update
    # TODO add authorization
    if @content_block.update(body: params[:html])
      render json: { status: { message: "Content block updated" }}
    else
      render json: { message: "Error updating content_block" }
    end
  end

  def destroy
    if @content_block.destroy
      render json: { status: { message: "Content block destroyed" }}
    else
      render json: { message: "Error destroying content_block" }
    end
  end

  def update_position
    if @content_block.insert_at(params[:position].to_i)
      render json: { status: { message: "Content block updated" }}
    else
      render json: { message: "Error updating content_block" }
    end
  end

  private

  def find_projekt
    if params[:projekt_id].present?
      @projekt = Projekt.find(params[:projekt_id])
    end
  end

  def find_content_block
    @content_block = SiteCustomization::ContentBlock.find(params[:id])
  end
end
