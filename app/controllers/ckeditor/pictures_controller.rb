# frozen_string_literal: true

class Ckeditor::PicturesController < ApplicationController
  def create
    picture = Ckeditor::Picture.new
    authorize! :create, picture

    image = params[:upload]
    resize_original = params[:resize_original] == "true"
    image_max_width = resize_original ? params[:width].to_i.presence : 1920
    image_max_height = resize_original ? params[:height].to_i.presence : 1080

    convered_image =
      if image.content_type != "image/gif"
        ImageProcessing::MiniMagick
          .source(image)
          .convert('jpg')
          .resize_to_fit(
            image_max_width,
            image_max_height
          )
          .saver(quality: 85, interlace: 'Line')
          .call
      else
        image
      end

    picture.attach_uploaded_file(image, convered_image)

    if picture.save
      original_url = picture.url_content(editor_id: params[:editor_id])

      json_to_render =
        picture.attributes.symbolize_keys.slice(*allowed_attributes).merge(
          url: original_url,
          thumb_url: picture.url_thumb(editor_id: params[:editor_id]),
          created_at: picture.created_at.strftime("%d.%m.%Y")
        )

      json_to_render[:custom_thumb_url] =
        if resize_original
          original_url
        else
          picture.custom_thumb_url(
            width: image_max_width,
            height: image_max_height
          )
        end

      render json: json_to_render
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

  private

    def picture_params
      params.require(:picture).permit(:title, :description, :alt_text)
    end

    def allowed_attributes
      %i[id data_file_name data_content_type data_file_size width height title description alt_text url thumb_url]
    end
end
