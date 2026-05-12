class FileManager::ImagesController < FileManager::BaseController
  def index
    authorize [:adm, :image], :index?
    skip_policy_scope

    @images =
      Image
        .for_file_manager(current_projekt)
        .order(created_at: :desc)
        .page(params[:page])
        .per(15)

    render layout: false
  end

  def create
    image = Image.new(
      user: current_user,
      admin: true,
      imageable: current_projekt,
      title: params[:upload]&.original_filename.to_s.first(80)
    )
    image.attachment = params[:upload]

    authorize [:adm, image], :create?

    if image.save
      render json: image_response(image)
    else
      render json: { error: { message: image.errors.full_messages.join(", ") } },
             status: :unprocessable_entity
    end
  end

  def update
    image = Image.find(params[:id])
    authorize [:adm, image]
    image.update!(image_params)

    render json: image.attributes.slice("id", "title")
  end

  def destroy
    image = Image.find(params[:id])
    authorize [:adm, image]
    image.destroy!

    render json: { status: "no_content" }
  end

  private

    def image_params
      params.require(:image).permit(:title)
    end

    def image_response(image)
      {
        id: image.id,
        title: image.title,
        content_type: image.attachment_content_type,
        url: image_variant_url(image, resize_to_limit: [1500, 2000]),
        gallery_thumb_url: image_variant_url(image, resize_to_limit: [600, 600]),
        custom_thumb_url: image_variant_url(image, resize_to_limit: [925, 925])
      }
    end

    def image_variant_url(image, transformations)
      Rails.application.routes.url_helpers.rails_representation_path(
        image.attachment.variant(transformations),
        only_path: true
      )
    end
end
