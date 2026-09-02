# A copy within this instance. The source is serialized first, exactly as it
# would be for another instance -- the bundle simply keeps its binaries and its
# references to rows only this instance has.
class Projekts::CopyService < ApplicationService
  def initialize(source:, copy:)
    @source = source
    @copy = copy
    @id_map = Projekts::Copying::IdMap.new
  end

  def call
    Projekts::Copying::CopyRunner.call(
      bundle: Projekts::SerializeForCopy.call(source: source),
      copy: copy,
      record_copier: record_copier,
      id_map: id_map
    )
  end

  private

    attr_reader :source, :copy, :id_map

    def record_copier
      Projekts::Copying::RecordCopier.new(
        id_map: id_map,
        reader: Projekts::Copying::AttributeReader.new(author: copy.author),
        blob_copier: Projekts::Copying::BlobCopier.new(id_map: id_map)
      )
    end
end
