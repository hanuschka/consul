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

  def variant(style)
    return attachment if style.blank?
    return if !attachment.attached?

    attachment_variant(**self.class.styles[style])
  end

  before_save :clear_generated_flags_on_replaced_attachment
  before_save :confirm_in_app_marking

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

    # A form can declare that a picture is AI-generated, which is a claim about
    # disclosure and safe to take at face value. It cannot be trusted to set
    # ai_generated_in_app, since that exempts the file from the EXIF strip and
    # would publish an uploader's camera GPS. So the claim is checked against
    # the bytes: only a picture that actually carries this app's marker gets
    # the exemption.
    #
    # Read from the pending upload rather than the stored blob: Active Storage
    # uploads in an after_commit, so at any earlier point the blob is not yet
    # readable from the service.
    def confirm_in_app_marking
      return if ai_generated_in_app? || !ai_generated?

      pending_attachment = attachment_changes["attachment"]
      return if pending_attachment.blank?

      if generated_marker?(pending_attachment.attachable)
        self.ai_generated_in_app = true
      end
    end

    def generated_marker?(attachable)
      case attachable
      when ActionDispatch::Http::UploadedFile
        marker_at?(attachable.tempfile.path)
      when ActiveStorage::Blob
        marker_in?(attachable.download)
      when String
        blob = ActiveStorage::Blob.find_signed(attachable)

        blob.present? && marker_in?(blob.download)
      else
        false
      end
    rescue StandardError => e
      Rails.logger.warn("[Image] marker check failed: #{e.message}")

      false
    end

    def marker_in?(bytes)
      file = Tempfile.new(["marker_check", ".jpg"], binmode: true)

      begin
        file.write(bytes)
        file.flush

        marker_at?(file.path)
      ensure
        file.close
        file.unlink
      end
    end

    def marker_at?(path)
      ::ExiftoolCommand.read_tag(
        path,
        ::Images::MarkAiGeneratedService::DIGITAL_SOURCE_TYPE_TAG
      ) == ::Images::MarkAiGeneratedService::TRAINED_ALGORITHMIC_MEDIA
    end

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
