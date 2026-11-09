# What the import loader says while it waits. It follows the analysis of the
# source and, for a copied Consul projekt, the final import too, which speaks
# with the chat's own submit-stage labels so both say the same thing.
module Adm::Projekts::ImportProgressHelper
  def import_progress_title(projekt_import)
    if projekt_import.submitting?
      t("adm.projekts.imports.chats.show.import_overlay_title")
    else
      t("adm.projekts.imports.show.processing_title")
    end
  end

  def import_progress_message(projekt_import)
    if projekt_import.submitting?
      t("adm.projekts.imports.chats.show.import_overlay_message")
    else
      t("adm.projekts.imports.show.processing_message")
    end
  end

  def import_progress_label(projekt_import)
    if projekt_import.submitting?
      stage = projekt_import.submit_stage.presence || "queued"

      import_submit_progress_labels.fetch(stage.to_sym, "")
    elsif projekt_import.processing?
      t("adm.projekts.imports.show.progress.processing")
    else
      t("adm.projekts.imports.show.progress.extracting")
    end
  end

  def import_submit_progress_labels
    t("adm.projekts.imports.chats.show.progress")
  end
end
