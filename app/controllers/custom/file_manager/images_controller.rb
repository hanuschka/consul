class FileManager::ImagesController < FileManager::BaseController
  def index
    authorize [:adm, :admin_image], :index?

    @images =
      AdminAssetsQuery
        .new(query_params.merge(type: "picture"))
        .call
        .with_attached_storage_data
        .merge(policy_scope([:adm, AdminImage]))
        .preload(projekt: :page)
        .page(params[:page])
        .per(15)

    render layout: false
  end

  def create
    picture = AdminImage.new(projekt: current_projekt, user: current_user)
    authorize [:adm, picture], :create?

    unless params[:upload].is_a?(ActionDispatch::Http::UploadedFile)
      return render json: { error: { message: t("files.upload_failed") } },
                    status: :unprocessable_entity
    end

    picture.attach_processed_upload(params[:upload])

    if picture.save
      render json: image_response(picture)
    else
      render json: { error: { message: picture.errors.full_messages.join(", ") } },
             status: :unprocessable_entity
    end
  end

  def show
    picture = AdminImage.find(params[:id])
    authorize [:adm, picture], :index?

    render json: image_show_response(picture)
  end

  def update
    picture = AdminImage.find(params[:id])
    authorize [:adm, picture]
    picture.update!(image_params)

    render json: picture.attributes.slice("id", "title")
  end

  def destroy
    picture = AdminImage.find(params[:id])
    authorize [:adm, picture]
    picture.destroy!

    render json: { status: "no_content" }
  end

  private

    def query_params
      params.permit(
        :search, :extension, :size_min_mb, :size_max_mb,
        :created_from, :created_to, :updated_from, :updated_to, :sort
      )
    end

    def image_params
      params.require(:image).permit(:title)
    end

    def image_response(picture)
      metadata = picture.storage_data.blob&.metadata || {}
      dimensions =
        if metadata[:width] && metadata[:height]
          { width: metadata[:width], height: metadata[:height] }
        end

      {
        id: picture.id,
        title: picture.title,
        content_type: picture.data_content_type,
        url: picture.url_content,
        gallery_thumb_url: picture.gallery_thumb_url,
        custom_thumb_url: picture.custom_thumb_url(width: 925),
        file_size: picture.data_file_size,
        dimensions: dimensions
      }
    end

    def image_show_response(picture)
      metadata = picture.storage_data.blob&.metadata || {}
      dimensions =
        if metadata[:width] && metadata[:height]
          "#{metadata[:width]} × #{metadata[:height]}"
        end

      projekt = picture.projekt
      projekt_page = projekt&.page

      {
        id: picture.id,
        title: picture.title,
        filename: picture.data_file_name,
        content_type: picture.data_content_type,
        file_size: picture.data_file_size,
        dimensions: dimensions,
        url: picture.url_content,
        preview_url: picture.custom_thumb_url(width: 600, height: 450),
        created_at: I18n.l(picture.created_at, format: :short),
        updated_at: I18n.l(picture.updated_at, format: :short),
        user_name: picture.user&.name,
        user_email: picture.user&.email,
        projekt_name: projekt_page&.title.presence || projekt&.name,
        projekt_url: projekt_page.present? ? page_path(projekt_page.slug) : nil
      }
    end
end
