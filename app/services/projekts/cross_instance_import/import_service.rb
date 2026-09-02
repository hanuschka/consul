# A copy of a projekt that lives on another instance. The bundle arrives already
# serialized and already stripped of everything only its instance could resolve,
# so from the runner's point of view it is the same copy as a local one.
class Projekts::CrossInstanceImport::ImportService < ApplicationService
  class UnsupportedFormatError < StandardError; end

  SUPPORTED_FORMAT_VERSIONS = [Projekts::SerializeForCopy::FORMAT_VERSION].freeze

  def initialize(bundle:, target:)
    @bundle = bundle
    @target = target
    @id_map = Projekts::Copying::IdMap.new
  end

  def call
    check_format_version
    adopt_source_name

    Projekts::Copying::CopyRunner.call(
      bundle: sanitized_bundle,
      copy: target,
      record_copier: record_copier,
      id_map: id_map
    )
  rescue UnsupportedFormatError => e
    ServiceResult.failure(error: e.message)
  end

  private

    attr_reader :bundle, :target, :id_map

    # Sanitized again on arrival. The sending instance already did it, but that
    # is the wrong side of the trust boundary to be the only one enforcing it:
    # the bundle passed through DT and came from a machine this one does not
    # control, and the copier assigns whatever columns it is handed. On a
    # well-formed export this pass changes nothing.
    def sanitized_bundle
      @sanitized_bundle ||= Projekts::Exporting::SanitizeBundle.call(bundle: bundle)
    end

    def record_copier
      Projekts::Copying::RecordCopier.new(
        id_map: id_map,
        reader: Projekts::Copying::AttributeReader.new(author: target.author),
        blob_copier: Projekts::Copying::BlobCopier.new(id_map: id_map)
      )
    end

    # An older instance can only have written a shape this one still knows.
    # Rebuilding half a projekt from an unread version is worse than refusing.
    def check_format_version
      version = bundle["format_version"]
      return if SUPPORTED_FORMAT_VERSIONS.include?(version)

      raise UnsupportedFormatError, "unsupported export format version #{version.inspect}"
    end

    # A local copy is named by its shell ("Copy of X") and the copier keeps that
    # name; an import is meant to arrive under the source's own. Renaming the
    # shell first is what lets both share one copier: the page title is restored
    # from the shell's name either way.
    def adopt_source_name
      name = sanitized_bundle.dig("projekt", "attributes", "name")
      return if name.blank?

      target.update!(name: name)
    end
end
