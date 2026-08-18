module DirectUploadsHelper
  def render_destroy_upload_link(direct_upload)
    label = direct_upload.resource_relation == "image" ? "images" : "documents"
    link_to tag.i(class: "fa fa-trash", aria: { hidden: true }), "#",
      class: "delete attachment-remove-icon remove-cached-attachment",
      title: t("#{label}.form.delete_button"),
      aria: { label: t("#{label}.form.delete_button") }
  end
end
