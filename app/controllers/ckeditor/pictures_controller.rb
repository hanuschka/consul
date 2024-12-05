# frozen_string_literal: true

class Ckeditor::PicturesController < ApplicationController
  skip_forgery_protection
  skip_authorization_check
  before_action :set_cors_headers

  def create
    picture = Ckeditor::Picture.new
    # authorize! :create, picture
    picture.attach_uploaded_file(params[:upload])

    if picture.save
      render json: { url: picture.url_content(editor_id: params[:editor_id]) }
    else
      render json: { error: { message: picture.errors.messages.values.flatten.join(", ") }}
    end
  end

  def update
    picture = Ckeditor::Picture.find(params[:id])
    # authorize! :update, picture
    picture.update!(picture_params)
    render json: { url: picture.url_content(editor_id: params[:editor_id]) }
  end

  def destroy
    picture = Ckeditor::Picture.find(params[:id])
    # authorize! :destroy, picture
    picture.destroy!
    render json: { status: :no_content }
  end

  def preflight_check
    head :ok
  end

  private

    def picture_params
      params.require(:picture).permit(:title, :description, :alt_text)
    end

    def set_cors_headers
      headers["Access-Control-Allow-Origin"] = "*"
      headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, PATCH, DELETE, OPTIONS" # Allow all HTTP methods
      headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization"
    end
end
