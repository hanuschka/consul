# frozen_string_literal: true

class Ckeditor::PicturesController < ApplicationController
  include Search

  def create
    picture = Ckeditor::Picture.new
    authorize! :create, picture

    image = params[:upload]
    width =  params[:width].to_i
    height = params[:height].to_i

    image_max_width = 3000 if width.zero?
    image_max_height = 2000 if height.zero?

    image_processing_pipeline = ImageProcessing::MiniMagick.source(image)

    image_processing_pipeline =
      if image.content_type != "image/gif"
        image_processing_pipeline
          .convert('jpg')
          .resize_to_fit(
            image_max_width,
            image_max_height
          )
          .saver(quality: 87, interlace: 'Line')
      else
        image_processing_pipeline
      end

    picture.attach_uploaded_file(
      image,
      image_processing_pipeline.call
    )

    if picture.save
      render json:
        picture.attributes.symbolize_keys.slice(*allowed_attributes).merge(
          url: picture.url_content(editor_id: params[:editor_id]),
          thumb_url: picture.url_thumb(editor_id: params[:editor_id]),
          gallery_thumb_url: picture.gallery_thumb_url,
          custom_thumb_url: picture.custom_thumb_url(width: 925),
          created_at: picture.created_at.strftime("%d.%m.%Y")
        )
    else
      render json: { error: { message: picture.errors.messages.values.flatten.join(", ") }}, status: :unprocessable_entity
    end
  end

  def update
    picture = Ckeditor::Picture.find(params[:id])
    authorize! :update, picture
    picture.update!(picture_params)
    render json: picture.attributes.symbolize_keys.slice(*allowed_attributes).merge(
      url: picture.url_content(editor_id: params[:editor_id]),
      thumb_url: picture.url_thumb(editor_id: params[:editor_id]),
      created_at: picture.created_at.strftime("%d.%m.%Y")
    )
  end

  def destroy
    picture = Ckeditor::Picture.find(params[:id])
    authorize! :destroy, picture
    picture.destroy!
    render json: { status: :no_content }
  end

  def custom_thumb_url
    picture = Ckeditor::Picture.find(params[:id])
    authorize! :update, picture

    width = params[:width].to_i
    height = params[:height].to_i
    pad = params[:pad].to_i

    width = 1200 if width.zero?
    height = 1200 if height.zero?

    thumb_url = picture.custom_thumb_url(
      width: width,
      height: height,
      pad: pad
    )

    render json: {
      id: picture.id,
      custom_thumb_url: thumb_url
    }
  end

  private

    def picture_params
      params.require(:picture).permit(:title, :description, :alt_text)
    end

    def allowed_attributes
      %i[id data_file_name data_content_type data_file_size width height title description alt_text url thumb_url]
    end
end
