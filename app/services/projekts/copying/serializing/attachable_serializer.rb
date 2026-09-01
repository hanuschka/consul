# Image and Document are the app's polymorphic attachment wrappers, carried by
# almost every record a projekt owns. The owner is queried rather than reflected
# on: rows exist for owner types that declare no association (Projekt carries
# Image rows without including Imageable). Image already preloads its attachment
# through a default scope; Document does not, hence the explicit preload.
class Projekts::Copying::Serializing::AttachableSerializer < ApplicationService
  def initialize(record:)
    @record = record
  end

  def call
    {
      "images" => nodes(Image, :imageable),
      "documents" => nodes(Document, :documentable)
    }
  end

  private

    attr_reader :record

    def nodes(model, owner_key)
      model.where(owner_key => record).with_attached_attachment.filter_map do |attachable|
        next if !attachable.attachment.attached?

        Projekts::Copying::Serializing::RecordSerializer.call(
          attachable, attachments: %i[attachment]
        )
      end
    end
end
