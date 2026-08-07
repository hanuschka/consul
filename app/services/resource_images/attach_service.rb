class ResourceImages::AttachService < ApplicationService
  # Attaching a picture to a proposal or a budget investment is the same three
  # steps whichever channel it arrived through: turn the payload into an
  # uploaded file, create the Image record when the resource has none, replace
  # the attachment when it already does.
  #
  # Extracted when WhatsApp became a second consumer alongside the web editor,
  # so the two cannot end up disagreeing about which of those branches applies.
  def self.from_base64(resource:, user:, base64:)
    tempfile = Base64ImageUtils.decode_to_tempfile(base64)

    return if tempfile.blank?

    new(
      resource: resource,
      user: user,
      tempfile: tempfile,
      filename: "ai_generated_#{Time.current.to_i}.jpg",
      content_type: "image/jpeg"
    ).call
  end

  # For bytes already in memory, which is what a downloaded WhatsApp media
  # object is.
  def self.from_bytes(resource:, user:, bytes:, content_type:)
    return if bytes.blank?

    # The helper answers with a bare extension ("jpg"), while both Tempfile and
    # a filename want it dotted.
    extension = ".#{Base64ImageUtils.extension_from_content_type(content_type)}"
    tempfile = Tempfile.new(["resource_image", extension])
    tempfile.binmode
    tempfile.write(bytes)
    tempfile.flush
    tempfile.rewind

    new(
      resource: resource,
      user: user,
      tempfile: tempfile,
      filename: "upload_#{Time.current.to_i}#{extension}",
      content_type: content_type
    ).call
  end

  def initialize(resource:, user:, tempfile:, filename:, content_type:)
    @resource = resource
    @user = user
    @tempfile = tempfile
    @filename = filename
    @content_type = content_type
  end

  def call
    return if @resource.blank? || @user.blank?

    return replace_attachment if @resource.image.present?

    Image.new(attachment: uploaded_file, user: @user, imageable: @resource).save!
  end

  private

    def uploaded_file
      @uploaded_file ||= ActionDispatch::Http::UploadedFile.new(
        tempfile: @tempfile,
        filename: @filename,
        type: @content_type
      )
    end

    def replace_attachment
      @resource.image.attachment.attach(uploaded_file)
    end
end
