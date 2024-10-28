
class Api::ImagesController < Api::BaseController
  skip_forgery_protection

  def create
    pictures = params[:images].map do |image|
      Ckeditor::Picture.new(data: image)
    end

    pictures.each(&:save)

    render json: pictures.map { |picture| serialize_picture(picture) }
  end

  def destroy
    # TODO
  end

  private

  def serialize_picture(picture)
    {
      name: picture.data_file_name,
      valid: picture.persisted?,
      url: url_for(picture.storage_data),
      thumb_url: url_for(picture.storage_data.variant(resize_to_limit: [280, 140]).processed),
      errors: picture.errors.messages.values.flatten
    }
  end
end
