module RelatedContentsHelper
  def show_related_contents_block?(relatable)
    !relatable.selected? &&
      projekt_phase_feature?(relatable.projekt_phase, "resource.show_related_content") &&
      (relatable.related_contents.any? || current_user&.present?)
  end
end
