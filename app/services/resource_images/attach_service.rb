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

  # A generated picture reaches the same place by a different route. The mark is
  # mandatory and has to be written before the bytes are attached, and the
  # marking service stages the in-app flag onto the Image record — which is why
  # the record is prepared here and saved once, at the end, rather than built
  # inside `call`.
  def self.from_generated_base64(resource:, user:, base64:, ai_system: nil, ai_system_version: nil)
    return if resource.blank? || user.blank?

    tempfile = Base64ImageUtils.decode_to_tempfile(base64)

    return if tempfile.blank?

    filename = "ai_generated_#{Time.current.to_i}.jpg"
    image = resource.image || resource.build_image(user: user)

    marking = ::Images::MarkAiGeneratedService.call(
      image: image,
      data: File.binread(tempfile.path),
      filename: filename,
      content_type: "image/jpeg",
      ai_system: ai_system.presence || ::DtApi::Resources::Ai::PROVIDER_NAME,
      ai_system_version: ai_system_version
    )

    image.attachment = ActionDispatch::Http::UploadedFile.new(
      tempfile: marked_tempfile(marking.data[:image_data]),
      filename: filename,
      type: "image/jpeg"
    )
    image.ai_generated = true
    image.save!

    resource.association(:image).reset

    image
  end

  def self.marked_tempfile(data)
    file = Tempfile.new(["ai_generated", ".jpg"], binmode: true)
    file.write(data)
    file.rewind

    file
  end
  private_class_method :marked_tempfile

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

    # Created through the resource's own association rather than as
    # `Image.new(imageable: @resource)`. The `present?` above has already loaded
    # `image` and cached it as nil, and `imageable` is a polymorphic belongs_to
    # with no inverse — so building the record from the child side leaves every
    # caller still holding a resource whose picture reads as missing. That is
    # what left the WhatsApp preview without its image.
    @resource.create_image!(attachment: uploaded_file, user: @user)
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
