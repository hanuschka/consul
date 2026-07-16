class Adm::Files::ImagesController < Adm::Files::BaseController
  def index
    authorize [:adm, :admin_image]

    @assets =
      AdminAssetsQuery
        .new(query_params.merge(type: "picture"))
        .call
        .with_attached_storage_data
        .merge(policy_scope([:adm, AdminImage]))
        .preload({ projekt: { page: :translations } }, user: :image)
        .page(params[:page])
        .per(24)

    @breadcrumbs = [
      { name: t("adm.menu.items.files"), icon: "folder" },
      { name: t("adm.menu.items.files_subitems.images") }
    ]

    render layout: !turbo_frame_request?
  end

  def show
    admin_image = AdminImage.find(params[:id])
    authorize [:adm, admin_image]

    @detail = ::Files::AdminImageShowComponent.new(record: admin_image)

    @breadcrumbs = [
      { name: t("adm.menu.items.files"), icon: "folder" },
      { name: t("adm.menu.items.files_subitems.images"), url: adm_files_images_path },
      { name: @detail.display_title }
    ]

    render layout: !turbo_frame_request?
  end

  private

    def query_params
      params.permit(
        :search, :extension, :size_min_mb, :size_max_mb,
        :created_from, :created_to, :updated_from, :updated_to, :sort
      )
    end
end
