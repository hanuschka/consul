# The bundle a copy is made from, made portable: the same serialization a local
# copy reads, with everything that only means something here taken back out.
class Projekts::SerializeForExport < ApplicationService
  FORMAT_VERSION = Projekts::SerializeForCopy::FORMAT_VERSION

  def initialize(source:)
    @source = source
  end

  def call
    Projekts::Exporting::SanitizeBundle.call(
      bundle: Projekts::SerializeForCopy.call(source: source)
    ).merge("source" => source_descriptor)
  end

  private

    attr_reader :source

    def source_descriptor
      {
        "projekt_id" => source.id,
        "page_slug" => source.page&.slug,
        "exported_at" => Time.current.iso8601
      }
    end
end
