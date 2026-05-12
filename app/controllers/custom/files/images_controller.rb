class Files::ImagesController < Files::BaseController
  def index
    authorize [:adm, :ckeditor_asset]
    skip_policy_scope

    @assets =
      CkeditorAssetsQuery
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

  private

    def query_params
      params.permit(
        :search, :extension, :size_min_mb, :size_max_mb,
        :created_from, :created_to, :updated_from, :updated_to, :sort
      ).merge(type: "picture")
    end
end
