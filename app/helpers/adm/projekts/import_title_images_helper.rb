module Adm::Projekts::ImportTitleImagesHelper
  # Small enough to stay sharp in the tile and in the summary next to the import
  # button, without asking Active Storage for a full-size variant of a print
  # resolution photo.
  TITLE_IMAGE_TILE_VARIANT = { resize_to_fill: [320, 200] }.freeze
  TITLE_IMAGE_SUMMARY_VARIANT = { resize_to_fill: [48, 32] }.freeze

  def import_title_image_tile_url(candidate)
    return nil if candidate.attachment.blank?

    rails_representation_url(candidate.attachment.variant(TITLE_IMAGE_TILE_VARIANT), only_path: true)
  end

  def import_title_image_summary_url(projekt_import)
    candidate = import_selected_title_image_candidate(projekt_import)
    return nil if candidate.blank?
    return nil if candidate.attachment.blank?

    rails_representation_url(candidate.attachment.variant(TITLE_IMAGE_SUMMARY_VARIANT), only_path: true)
  end

  # What the import will actually do, said in one line so an admin about to press
  # Import never has to scroll back to the picker to find out.
  def import_title_image_summary(projekt_import)
    return t("adm.projekts.imports.title_image.summary.generated") if projekt_import.title_image_generated?
    return t("adm.projekts.imports.title_image.summary.none") if projekt_import.title_image_none?

    candidate = import_selected_title_image_candidate(projekt_import)
    return t("adm.projekts.imports.title_image.summary.unavailable") if candidate.blank?

    t("adm.projekts.imports.title_image.summary.document",
      width: candidate.width, height: candidate.height)
  end

  def import_selected_title_image_candidate(projekt_import)
    return nil if !projekt_import.title_image_document?

    projekt_import
      .source_image_candidates
      .find { |candidate| candidate.index == projekt_import.title_image_index }
  end

  # Written back into the chat as the assistant's reply, so the admin sees which
  # option a typed number was read as.
  def import_title_image_confirmation(projekt_import)
    return t("adm.projekts.imports.title_image.confirmed.generated") if projekt_import.title_image_generated?
    return t("adm.projekts.imports.title_image.confirmed.none") if projekt_import.title_image_none?

    candidate = import_selected_title_image_candidate(projekt_import)
    return t("adm.projekts.imports.title_image.confirmed.none") if candidate.blank?

    t("adm.projekts.imports.title_image.confirmed.document",
      number: candidate.index + 1, width: candidate.width, height: candidate.height)
  end

  # The picture is right there in the row, so the line above it names where it came
  # from — which is what an admin looking at two similar photos from two uploaded
  # files actually needs.
  def import_title_image_option_title(option)
    return option.candidate.source_filename.presence || option.candidate.filename if option.document?

    t("adm.projekts.imports.title_image.options.#{option.mode}")
  end

  def import_title_image_option_meta(option)
    if option.document?
      return t("adm.projekts.imports.title_image.dimensions",
               width: option.candidate.width, height: option.candidate.height)
    end

    t("adm.projekts.imports.title_image.option_hints.#{option.mode}")
  end

  def import_title_image_option_icon(option)
    return "broken_image" if option.document?
    return "auto_awesome" if option.mode == "generated"

    "hide_image"
  end

  # The visible label is short so every row reads the same width; the full sentence
  # goes to assistive technology, where "Auswählen" on its own says nothing. The
  # alternatives already read as instructions ("Kein Titelbild"), so only a
  # filename needs the sentence built around it.
  def import_title_image_option_action_label(option)
    return import_title_image_option_title(option) if !option.document?

    t("adm.projekts.imports.title_image.use_option",
      option: import_title_image_option_title(option))
  end

  def import_title_image_selected?(projekt_import, option)
    return projekt_import.title_image_mode == option.mode if !option.document?

    projekt_import.title_image_document? && projekt_import.title_image_index == option.index
  end

  def import_title_image_ineligible_hint(candidate)
    return nil if candidate.eligible

    t("adm.projekts.imports.title_image.ineligible.#{candidate.ineligible_reason}",
      minimum_height: ::Image::MIN_IMAGE_HEIGHT)
  end
end
