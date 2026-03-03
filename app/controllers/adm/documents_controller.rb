module Adm
  class DocumentsController < Adm::BaseController
    def index
      authorize [:adm, :document]
      skip_policy_scope

      @pagy, @documents = pagy(policy_scope([:adm, Document]))

      @breadcrumbs = [
        { name: t("adm.menu.items.application") },
        { name: t("adm.menu.items.application_subitems.documents") }
      ]
    end

    def new
      @document = Document.new
      authorize [:adm, @document]

      @breadcrumbs = [
        { name: t("adm.menu.items.application") },
        { name: t("adm.menu.items.application_subitems.documents"), url: adm_documents_path },
        { name: t(".title") }
      ]
    end

    def create
      @document = initialize_document
      authorize [:adm, @document]

      if @document.save
        redirect_to adm_documents_path,
          notice: t("admin.documents.create.success_notice")
      else
        flash.now[:error] = t("admin.documents.create.unable_notice")
        render :new
      end
    end

    def destroy
      @document = Document.find(params[:id])
      authorize [:adm, @document]

      @document.destroy!

      redirect_to adm_documents_path,
        notice: t("admin.documents.destroy.success_notice")
    end

    private

      def initialize_document
        document = Document.new
        document.attachment = params.dig(:document, :attachment)
        document.title = document.attachment_file_name
        document.user = current_user
        document.admin = true
        document
      end
  end
end


