module ProjektContentBlocksAdminActions
  extend ActiveSupport::Concern

  included do
    before_action :set_namespace
    before_action :find_projekt, only: [:create]
    before_action :find_content_block, only: [
      :destroy, :update, :update_position, :change_with_ai
    ]
  end

  def create
    authorize!(:update, @projekt)

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

      render json: { content_block: {id: @content_block.id}, status: { message: "Content block created" }}
    else
      render json: { message: "Error creating content block" }
    end
  end

  def update
    authorize!(:update, @content_block.projekt)

    if @content_block.update(body: params[:html])
      render json: { status: { message: "Content block updated" }}
    else
      render json: { message: "Error updating content block" }
    end
  end

  def destroy
    authorize!(:update, @content_block.projekt)

    if @content_block.destroy
      render json: { status: { message: "Content block destroyed" }}
    else
      render json: { message: "Error destroying content_block" }
    end
  end

  def update_position
    authorize!(:update, @content_block.projekt)

    if @content_block.insert_at(params[:position].to_i)
      render json: { status: { message: "Content block position updated" }}
    else
      render json: { message: "Error updating content block position" }
    end
  end

  def change_with_ai
    authorize!(:update, @content_block.projekt)

    llm_response = RubyLLM.chat(model: 'gpt-5-nano').ask(
      <<~TEXT
        Update the content block html using provided instructions.
        Instructions: '#{params[:instructions]}'.
        When requested to add images use "https://placehold.co" for src.
        Dont replace existing images.
        For instance: "https://placehold.co/275x275".

        Current content block html content:
        #{params[:content_block_html]}

        Return just new html.
      TEXT
    )

    new_content_block_body = llm_response.content

    if new_content_block_body.present?
      render json: { content_block_html: new_content_block_body, status: { message: "Content block updated" }}
    else
      render json: { status: { message: "Error generating content block with ai" }}
    end
  end

  private

  def find_projekt
    if params[:projekt_id].present?
      @projekt = Projekt.find(params[:projekt_id])
    end
  end

  def find_content_block
    @content_block = ::SiteCustomization::ContentBlock.find(params[:id])
  end

  def set_namespace
    @namespace = params[:controller].split("/").first.to_sym
  end
end
