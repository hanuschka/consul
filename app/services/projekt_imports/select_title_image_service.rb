# Records the admin's choice of title image. The three modes are exclusive by
# construction — one column holds which kind of image the projekt gets, and the
# index only means anything for a picture out of the documents — so no combination
# of clicks can ask for an AI banner and a document photo at the same time.
class ProjektImports::SelectTitleImageService < ApplicationService
  attr_reader :projekt_import, :mode, :index

  def initialize(projekt_import:, mode:, index: nil)
    @projekt_import = projekt_import
    @mode = mode.to_s
    @index = index
  end

  def call
    if !ProjektImport.title_image_modes.key?(mode)
      return ServiceResult.failure(error: I18n.t("adm.projekts.imports.errors.unknown_title_image_mode"))
    end

    return select_document_image if mode == "document"

    projekt_import.update!(title_image_mode: mode, title_image_index: nil)

    ServiceResult.success(projekt_import: projekt_import)
  end

  private

  # The index is checked against the stored images rather than trusted: it arrives
  # from the browser, and neither an out of range one — which would silently leave
  # the projekt with no title image after the admin had picked a picture — nor a
  # negative one, which Array#[] would resolve to some other image entirely, may
  # reach the column.
  def select_document_image
    return unknown_image_failure if !index.to_s.match?(/\A\d+\z/)

    candidate = projekt_import.source_image_candidates[index.to_i]
    return unknown_image_failure if candidate.blank?

    if !candidate.eligible?
      return ServiceResult.failure(error: I18n.t("adm.projekts.imports.errors.title_image_ineligible"))
    end

    projekt_import.update!(title_image_mode: "document", title_image_index: index.to_i)

    ServiceResult.success(projekt_import: projekt_import)
  end

  def unknown_image_failure
    ServiceResult.failure(error: I18n.t("adm.projekts.imports.errors.unknown_title_image"))
  end
end
