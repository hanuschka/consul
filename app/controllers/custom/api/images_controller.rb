
class Api::ImagesController < Api::BaseController
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
      thumb_url: picture.persisted? && url_for(picture.storage_data.variant(resize_to_fill: [504, 252]).processed),
      errors: picture.errors.messages.values.flatten
    }
  end
end
