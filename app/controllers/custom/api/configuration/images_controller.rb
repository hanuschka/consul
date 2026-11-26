class Api::Configuration::ImagesController < Api::Configuration::BaseController
  UNCHECKED_SIZE_IMAGE_NAMES = (
    SiteCustomization::Image::LOGO_IMAGE_NAMES + %w[header_image mobile_header_image]
  ).freeze

  before_action :find_image_slot, only: [:update, :destroy]

  def index
    images_by_name = SiteCustomization::Image.with_attached_image.index_by(&:name)
    image_slots = SiteCustomization::Image::VALID_IMAGES.keys.map do |name|
      serialize(images_by_name[name] || SiteCustomization::Image.new(name:))
    end

    render json: { data: { images: image_slots } }
  end

  def update
    previous_blob = @image_slot.persisted_image&.blob
    @image_slot.image = decoded_attachment(params.dig(:image, :attachment), @image_slot.name)

    if @image_slot.save
      audit_attachment_change(@image_slot, :image, previous_blob, @image_slot.image.blob)

      render json: { data: { image: serialize(@image_slot) } }
    else
      render_record_errors(@image_slot)
    end
  end

  def destroy
    previous_blob = @image_slot.persisted_image&.blob

    if previous_blob
      @image_slot.image.purge
      audit_attachment_change(@image_slot, :image, previous_blob, nil)
    end

    render json: { data: { image: serialize(@image_slot.reload) } }
  end

  private

    def find_image_slot
      if !SiteCustomization::Image::VALID_IMAGES.key?(params[:name])
        raise ActiveRecord::RecordNotFound
      end

      @image_slot = SiteCustomization::Image.find_or_create_by!(name: params[:name])
    end

    def serialize(image_slot)
      {
        name: image_slot.name,
        required_width: image_slot.required_width,
        required_height: image_slot.required_height,
        size_rule: size_rule(image_slot.name),
        image: serialize_attachment(image_slot.persisted_image)
      }
    end

    def size_rule(name)
      if name.in?(UNCHECKED_SIZE_IMAGE_NAMES)
        "any"
      elsif name.in?(SiteCustomization::Image::MIN_DIMENSION_IMAGE_NAMES)
        "minimum"
      else
        "exact"
      end
    end
end
