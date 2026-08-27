require_dependency Rails.root.join("app", "models", "image").to_s

class Image
  # Uploaded photographs carry camera EXIF, including GPS, that must never
  # reach a public rendering -- so every variant strips metadata by default.
  # A picture this app generated has nothing to leak and its IPTC marker is
  # what makes it detectable as AI-generated, so stripping that would undo the
  # marking.
  #
  # Named after the attachment rather than taking over #variant, which already
  # means "render one of the styles declared on the class".
  def attachment_variant(**options)
    return attachment.variant(**options) if ai_generated_in_app?

    attachment.variant(**options, strip: true)
  end

  before_save :clear_generated_flags_on_replaced_attachment

  # Writers that mean to keep or set a flag assign it in the same save; a path
  # that only swaps the file (the /adm banner upload, an API update that omits
  # the key) leaves them untouched, and neither flag must survive onto a
  # picture nobody declared.
  #
  # ai_generated_in_app in particular is what exempts a picture from the EXIF
  # strip, so carrying it over to a replacement would publish the uploader's
  # camera metadata.
  def ai_generated=(value)
    @ai_generated_assigned = true
    super
  end

  def ai_generated_in_app=(value)
    @ai_generated_in_app_assigned = true
    super
  end

  private

    def clear_generated_flags_on_replaced_attachment
      # The declarations count for one save, so they are consumed here rather
      # than left for the next save of the same in-memory record to inherit.
      ai_declared = @ai_generated_assigned
      in_app_declared = @ai_generated_in_app_assigned
      @ai_generated_assigned = false
      @ai_generated_in_app_assigned = false

      return if attachment_changes["attachment"].blank?

      if !ai_declared && ai_generated?
        self.ai_generated = false
      end

      if !in_app_declared && ai_generated_in_app?
        self.ai_generated_in_app = false
      end

      @ai_generated_assigned = false
      @ai_generated_in_app_assigned = false
    end
end
