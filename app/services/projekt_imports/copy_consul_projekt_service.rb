# Builds the projekt at the end of a Consul-projekt import: the shell is
# created only now, once the admin has finished the review step, so a fetch or
# a review that never got that far leaves no half-built projekt behind.
#
# It stays inactive until an admin releases it, which is also what keeps it out
# of navigation and the overview in the meantime.
class ProjektImports::CopyConsulProjektService < ApplicationService
  def initialize(projekt_import:)
    @projekt_import = projekt_import
  end

  def call
    bundle = read_bundle
    return failure("bundle_missing") if bundle.blank?

    projekt = Projekt.create!(
      name: projekt_import.overlay["name"].presence || bundle.dig("projekt", "attributes", "name"),
      author: projekt_import.user,
      parent_id: nil,
      activated: false
    )
    projekt_import.record_created_projekt!(projekt)

    copy_result = ::Projekts::CrossInstanceImport::ImportService.call(bundle: bundle, target: projekt)
    return copy_failure(copy_result, projekt) if !copy_result.success?

    apply_overlay(projekt, copy_result.data[:id_map])

    ServiceResult.success(projekt: projekt, skipped_blobs: copy_result.data[:skipped_blobs])
  end

  private

    attr_reader :projekt_import

    def read_bundle
      return nil if !projekt_import.source_bundle.attached?

      JSON.parse(projekt_import.source_bundle.download)
    rescue JSON::ParserError
      nil
    end

    def apply_overlay(projekt, id_map)
      ProjektImports::ApplyBundleOverlayService.call(
        projekt: projekt,
        overlay: projekt_import.overlay,
        id_map: id_map,
        locale: projekt_import.import_locale
      )
    end

    # The projekt is kept rather than deleted: the copier stops inside a
    # transaction, so what survives is a shell the admin can look at and remove,
    # and deleting it here would take the record the failure points at with it.
    def copy_failure(copy_result, projekt)
      ServiceResult.failure(
        error: copy_result.error,
        error_details: (copy_result.error_details || {}).merge("created_projekt_id" => projekt.id)
      )
    end

    def failure(reason)
      ServiceResult.failure(
        error: I18n.t("adm.projekts.imports.errors.consul_projekt.#{reason}"),
        error_details: { "reason" => reason }
      )
    end
end
