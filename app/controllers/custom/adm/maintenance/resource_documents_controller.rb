class Adm::Maintenance::ResourceDocumentsController < Adm::Maintenance::BaseController
  def index
    authorize [:adm, :document]

    @assets =
      DocumentsQuery
        .new(query_params.merge(admin_flag: "false"))
        .call
        .with_attached_attachment
        .merge(policy_scope([:adm, Document]))
        .preload(:documentable, user: :image)
        .page(params[:page])
        .per(24)

    ::Files::ResourcePreloader.call(@assets.map(&:documentable))

    @breadcrumbs = [
      { name: t("adm.menu.items.files"), icon: "folder" },
      { name: t("adm.menu.items.files_subitems.resource_documents") }
    ]

    render layout: !turbo_frame_request?
  end

  def show
    document = Document.find(params[:id])
    authorize [:adm, document]

    @detail = ::Files::DocumentShowComponent.new(record: document)

    @breadcrumbs = [
      { name: t("adm.menu.items.files"), icon: "folder" },
      { name: t("adm.menu.items.files_subitems.resource_documents"), url: adm_maintenance_resource_documents_path },
      { name: @detail.display_title }
    ]

    render layout: !turbo_frame_request?
  end

  def documentable_type_filter
    authorize [:adm, :document], :index?

    @documentable_types = DocumentsQuery.available_documentable_types(Document.where(admin: false))
    @selected = params[:documentable_type]

    render layout: false
  end

  private

    def query_params
      params.permit(
        :search, :extension, :size_min_mb, :size_max_mb,
        :created_from, :created_to, :updated_from, :updated_to,
        :documentable_type, :sort
      )
    end
end
