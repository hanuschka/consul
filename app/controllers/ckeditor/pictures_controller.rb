# frozen_string_literal: true

class Ckeditor::PicturesController < ApplicationController
  def create
    picture = Ckeditor::Picture.new
    authorize! :create, picture
    picture.attach_uploaded_file(params[:upload])

    if picture.save
      render json: { url: picture.url_content }
    else
      render json: { error: { message: picture.errors.messages.values.flatten.join(", ") }}
    end
  end

  private

    def picture_params
      {
        data_file_name: params[:upload].original_filename,
        data_content_type: params[:upload].content_type,
        data_file_size: params[:upload].size,
        type: "Ckeditor::Picture",
        storage_data: params[:upload].tempfile
      }
    end
end
