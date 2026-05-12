class Adm::Files::DocumentsController < Adm::Files::BaseController
  def index
    authorize [:adm, :document]
    skip_policy_scope

    @assets =
      DocumentsQuery
        .new(query_params)
        .call
        .page(params[:page])
        .per(24)

    @breadcrumbs = [
      { name: t("adm.menu.items.files"), icon: "folder" },
      { name: t("adm.menu.items.files_subitems.documents") }
    ]

    render layout: !request.xhr?
  end

  def update
    document = Document.find(params[:id])
    authorize [:adm, document]
    document.update!(document_params)

    render json: document.attributes.slice("id", "title")
  end

  def documentable_type_filter
    authorize [:adm, :document], :index?

    @documentable_types = DocumentsQuery.available_documentable_types
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

    def document_params
      params.require(:document).permit(:title)
    end
end
