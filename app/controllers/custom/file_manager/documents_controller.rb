class FileManager::DocumentsController < FileManager::BaseController
  def index
    authorize [:adm, :document], :index?

    @documents =
      Document
        .admin
        .merge(policy_scope([:adm, Document]))
        .preload(:documentable)
        .order(created_at: :desc)
        .page(params[:page])
        .per(15)

    render layout: false
  end

  def create
    document = Document.new(
      user: current_user,
      admin: true,
      documentable: current_projekt,
      title: params[:upload]&.original_filename.to_s
    )
    document.attachment = params[:upload]

    authorize [:adm, document], :create?

    if document.save
      render json: document_response(document)
    else
      render json: { error: { message: document.errors.full_messages.join(", ") } },
             status: :unprocessable_entity
    end
  end

  def show
    document = Document.find(params[:id])
    authorize [:adm, document], :index?

    render document_info_component(document), layout: false
  end

  def update
    document = Document.find(params[:id])
    authorize [:adm, document]
    document.update!(document_params)

    render json: document.attributes.slice("id", "title")
  end

  def destroy
    document = Document.find(params[:id])
    authorize [:adm, document]
    document.destroy!

    render json: { status: "no_content" }
  end

  private

    def document_params
      params.require(:document).permit(:title)
    end

    def document_response(document)
      {
        id: document.id,
        title: document.title,
        content_type: document.attachment_content_type,
        url: Rails.application.routes.url_helpers.rails_blob_path(
          document.attachment, only_path: true
        ),
        file_size: document.attachment_file_size
      }
    end

    def document_info_component(document)
      projekt =
        if document.documentable_type == "Projekt"
          document.documentable
        end

      ProjektStudio::FileInfoComponent.new(
        title: document.title,
        filename: document.attachment_file_name,
        content_type: document.attachment_content_type,
        file_size: document.attachment_file_size,
        file_url: Rails.application.routes.url_helpers.rails_blob_path(
          document.attachment, only_path: true
        ),
        created_at: document.created_at,
        updated_at: document.updated_at,
        user_name: document.user&.name,
        user_email: document.user&.email,
        projekt: projekt
      )
    end
end
