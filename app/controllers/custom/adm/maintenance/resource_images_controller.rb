class Adm::Maintenance::ResourceImagesController < Adm::Maintenance::BaseController
  EXCLUDED_IMAGEABLE_TYPES = %w[User].freeze

  def index
    authorize [:adm, :image]

    @assets =
      ImagesQuery
        .new(query_params)
        .call
        .where("images.imageable_type IS DISTINCT FROM ?", "User")
        .merge(policy_scope([:adm, Image]))
        .preload(:imageable, user: :image)
        .page(params[:page])
        .per(24)

    ::Files::ResourcePreloader.call(@assets.map(&:imageable))

    @breadcrumbs = [
      { name: t("adm.menu.items.files"), icon: "folder" },
      { name: t("adm.menu.items.files_subitems.resource_images") }
    ]

    render layout: !turbo_frame_request?
  end

  def show
    image = Image.find(params[:id])
    authorize [:adm, image]

    @detail = ::Files::ImageShowComponent.new(record: image)

    @breadcrumbs = [
      { name: t("adm.menu.items.files"), icon: "folder" },
      { name: t("adm.menu.items.files_subitems.resource_images"), url: adm_maintenance_resource_images_path },
      { name: @detail.display_title }
    ]

    render layout: !turbo_frame_request?
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

  def imageable_type_filter
    authorize [:adm, :image], :index?

    @imageable_types = ImagesQuery.available_imageable_types - EXCLUDED_IMAGEABLE_TYPES
    @selected = params[:imageable_type]

    render layout: false
  end

  private

    def query_params
      params.permit(
        :search, :extension, :size_min_mb, :size_max_mb,
        :created_from, :created_to, :updated_from, :updated_to,
        :imageable_type, :sort
      )
    end

    def image_params
      params.require(:image).permit(:title)
    end
end
