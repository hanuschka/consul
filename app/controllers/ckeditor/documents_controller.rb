# frozen_string_literal: true

class Ckeditor::DocumentsController < ApplicationController
  skip_forgery_protection
  skip_authorization_check

  def create
    document = Ckeditor::Document.new
    # authorize! :create, document
    document.attach_uploaded_file(params[:upload])

    if document.save
      render json: { url: document.url_content(editor_id: params[:editor_id]) }
    else
      render json: { error: { message: document.errors.messages.values.flatten.join(", ") }}
    end
  end

  def update
    document = Ckeditor::Document.find(params[:id])
    # authorize! :update, document
    document.update!(document_params)
    render json: { url: document.url_content(editor_id: params[:editor_id]) }
  end

  def destroy
    document = Ckeditor::Document.find(params[:id])
    # authorize! :destroy, document
    document.destroy!
    render json: { status: :no_content }
  end

  private

    def document_params
      params.require(:document).permit(:title, :description)
    end
end
