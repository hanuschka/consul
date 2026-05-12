class FileManager::DocumentsController < FileManager::BaseController
  def index
    authorize [:adm, :document], :index?
    skip_policy_scope

    @documents =
      Document
        .for_studio_file_manager(current_projekt)
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
        url: Rails.application.routes.url_helpers.url_for(document.attachment),
        file_size: document.attachment_file_size
      }
    end
end
