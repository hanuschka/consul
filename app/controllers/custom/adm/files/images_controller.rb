class Adm::Files::ImagesController < Adm::Files::BaseController
  def index
    authorize [:adm, :image]
    skip_policy_scope

    @assets =
      ImagesQuery
        .new(query_params)
        .call
        .page(params[:page])
        .per(24)

    @breadcrumbs = [
      { name: t("adm.menu.items.files"), icon: "folder" },
      { name: t("adm.menu.items.files_subitems.images") }
    ]

    render layout: !request.xhr?
  end

  def update
    image = Image.find(params[:id])
    authorize [:adm, image]
    image.update!(image_params)

    render json: image.attributes.slice("id", "title")
  end

  def imageable_type_filter
    authorize [:adm, :image], :index?

    @imageable_types = ImagesQuery.available_imageable_types
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
