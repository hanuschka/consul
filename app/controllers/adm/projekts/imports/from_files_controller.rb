class Adm::Projekts::Imports::FromFilesController < Adm::Projekts::BaseController
  MAX_AGGREGATE_BYTES = 500.megabytes
  # A single document this large is rejected before the upload starts rather
  # than after half a gigabyte has travelled to a worker that cannot read it.
  MAX_FILE_BYTES = 100.megabytes
  ALLOWED_EXTENSIONS = %w[pdf docx odt txt md].freeze

  before_action :authorize_create

  def new
    @projekt_import = current_user.projekt_imports.build(source_kind: "file")
    @missing_tools = ProjektImports::RequiredTools.missing

    @breadcrumbs = [
      { name: t("adm.projekts.home.title"), url: adm_projekts_root_path },
      { name: t("adm.projekts.imports.index.title"), url: adm_projekts_imports_path },
      { name: t("adm.projekts.imports.from_files.new.title") }
    ]
  end

  def create
    files = Array(params[:files]).reject(&:blank?)

    error = validation_error_for(files)
    if error.present?
      respond_with_error(error)
      return
    end

    @projekt_import = current_user.projekt_imports.create!(
      source_kind: "file",
      status: "pending",
      additional_user_instructions: params[:additional_user_instructions].presence
    )
    files.each { |file| @projekt_import.source_files.attach(file) }

    ProjektImports::FromFileJob.perform_later(@projekt_import.id)

    render json: {
      id: @projekt_import.id,
      status: @projekt_import.status,
      import_url: adm_projekts_import_path(@projekt_import)
    }
  end

  private

    def authorize_create
      authorize [:adm, :projekts, Projekt], :create?
    end

    def validation_error_for(files)
      return t("adm.projekts.imports.errors.no_files") if files.empty?

      oversized = files.find { |file| file.size.to_i > MAX_FILE_BYTES }
      if oversized
        return t("adm.projekts.imports.errors.file_too_large",
          filename: oversized.original_filename,
          size: helpers.number_to_human_size(MAX_FILE_BYTES))
      end

      total_bytes = files.sum { |file| file.size.to_i }
      if total_bytes > MAX_AGGREGATE_BYTES
        return t("adm.projekts.imports.errors.too_large")
      end

      invalid = files.find { |file| !allowed_extension?(file) }
      return if invalid.blank?

      t("adm.projekts.imports.errors.unsupported_type", filename: invalid.original_filename)
    end

    def allowed_extension?(file)
      ext = File.extname(file.original_filename).delete(".").downcase
      ALLOWED_EXTENSIONS.include?(ext)
    end

    def respond_with_error(message)
      respond_to do |format|
        format.json { render json: { error: message }, status: :unprocessable_entity }
        format.html do
          flash[:error] = message
          redirect_to new_adm_projekts_imports_from_file_path
        end
      end
    end
end
