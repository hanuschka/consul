class Adm::Files::ImagesController < Adm::Files::BaseController
  def index
    authorize [:adm, :admin_image]

    @assets =
      AdminAssetsQuery
        .new(query_params.merge(type: "picture"))
        .call
        .with_attached_storage_data
        .merge(policy_scope([:adm, AdminImage]))
        .page(params[:page])
        .per(24)

    @breadcrumbs = [
      { name: t("adm.menu.items.files"), icon: "folder" },
      { name: t("adm.menu.items.files_subitems.images") }
    ]

    render layout: !request.xhr?
  end

  private

    def query_params
      params.permit(
        :search, :extension, :size_min_mb, :size_max_mb,
        :created_from, :created_to, :updated_from, :updated_to, :sort
      )
    end
end
