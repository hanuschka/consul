module ProjektContentBlocksAdminActions
  extend ActiveSupport::Concern
  include AiErrorHandling

  included do
    before_action :set_namespace
    before_action :find_projekt, only: [:create, :import_document, :destroy_all]
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

    update_params = {}
    update_params[:body] = params[:html] if params.key?(:html)
    update_params[:margin_bottom] = params[:margin_bottom] if params.key?(:margin_bottom)

    if @content_block.update(update_params)
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

    return unless check_ai_model_configured

    use_full_projekt_context = ActiveModel::Type::Boolean.new.cast(params[:use_full_projekt_context])

    new_content_block_body =
      Ai::GenerateContentBlock.call(
        params[:instructions],
        params[:content_block_html],
        @content_block.projekt.page&.title,
        @content_block.projekt.page&.subtitle,
        projekt: @content_block.projekt,
        use_full_projekt_context: use_full_projekt_context
      )

    if new_content_block_body.present?
      render json: { content_block_html: new_content_block_body, status: { message: "Content block updated" }}
    else
      render json: { status: { message: I18n.t("ai.errors.generation_failed") }}
    end
  end

  def import_document
    authorize!(:update, @projekt)

    unless params[:file].present?
      return render(
        json: { error: { message: "Keine Datei hochgeladen" }},
        status: :unprocessable_entity
      )
    end

    file = params[:file]

    result = Projekts::BuildFromDocument.call(
      projekt: @projekt,
      file: file
    )

    if result.success?
      render json: {
        content_blocks: result.content_blocks_data,
        status: { message: "Dokument erfolgreich importiert" }
      }
    else
      render(
        json: {
          error: {
            message: result.error,
            fallback_text: result.fallback_text
          }
        },
        status: :unprocessable_entity
      )
    end
  end

  def destroy_all
    authorize!(:update, @projekt)

    @projekt.content_blocks.destroy_all

    redirect_back(
      fallback_location: root_path,
      notice: "Alle Inhaltsblöcke gelöscht"
    )
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
