# frozen_string_literal: true

class Ckeditor::PicturesController < ApplicationController
  skip_forgery_protection
  skip_authorization_check

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

  private

    def picture_params
      params.require(:picture).permit(:title, :description, :alt_text)
    end
end
