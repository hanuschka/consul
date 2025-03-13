# frozen_string_literal: true

class Ckeditor::DocumentsController < ApplicationController
  def create
    document = Ckeditor::Document.new
    authorize! :create, document
    document.attach_uploaded_file(params[:upload])

    if document.save
      render json: document.attributes.symbolize_keys.slice(*allowed_attributes).merge(
        url: document.url_content(editor_id: params[:editor_id]),
        created_at: asset.created_at.strftime("%d.%m.%Y")
      )
    else
      render json: { error: { message: document.errors.messages.values.flatten.join(", ") }}
    end
  end

  def update
    document = Ckeditor::Document.find(params[:id])
    authorize! :update, document
    document.update!(document_params)
    render json: document.attributes.symbolize_keys.slice(*allowed_attributes).merge(
      url: document.url_content(editor_id: params[:editor_id]),
      created_at: asset.created_at.strftime("%d.%m.%Y")
    )
  end

  def destroy
    document = Ckeditor::Document.find(params[:id])
    authorize! :destroy, document
    document.destroy!
    render json: { status: :no_content }
  end

  private

    def document_params
      params.require(:document).permit(:title, :description)
    end

    def allowed_attributes
      %i[id data_file_name data_content_type data_file_size width height title description alt_text url thumb_url]
    end
end
