module Adm::Projekts::ImportPathsHelper
  # The screen an import goes back to when it is started over. Each source has
  # its own, so "upload another file" and "try another address" are the same
  # action asked of different records.
  def import_source_new_path(projekt_import)
    case projekt_import.source_kind
    when "url" then new_adm_projekts_imports_from_url_path
    when "consul_projekt" then new_adm_projekts_imports_from_consul_projekt_path
    else new_adm_projekts_imports_from_file_path
    end
  end

  # Where the admin says what should still change before the projekt is built.
  # An AI-negotiated import gets the chat; a copied Consul projekt gets the
  # plain review form, which is also what keeps it working with AI switched off.
  def import_review_path(projekt_import, **options)
    if projekt_import.ai_negotiated?
      adm_projekts_import_chat_path(projekt_import, **options)
    else
      adm_projekts_import_review_path(projekt_import, **options)
    end
  end

  def import_source_label(projekt_import)
    t("adm.projekts.imports.sources.#{projekt_import.source_kind}.label")
  end

  # Where this import's material actually came from — the address, or the
  # filenames it was read out of. Names the thing the admin has to judge, which
  # the source kind alone ("Aus einer Datei") does not.
  def import_source_description(projekt_import)
    return projekt_import.source_url if projekt_import.source_url.present?

    filenames = projekt_import.source_files.map { |file| file.filename.to_s }
    return import_source_label(projekt_import) if filenames.empty?

    filenames.join(", ")
  end

  def import_failure_stage_label(projekt_import)
    stage = projekt_import.failure_stage.presence
    return nil if stage.blank?

    t("adm.projekts.imports.failure_stages.#{stage}",
      default: t("adm.projekts.imports.failure_stages.unknown"))
  end
end
