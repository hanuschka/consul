module ImageMetadataStripper
  module UploadHook
    def upload
      return super if !strip_metadata_on_upload?

      case attachable
      when ActionDispatch::Http::UploadedFile, Rack::Test::UploadedFile
        upload_from_copy(attachable.open)
      when Hash
        upload_from_copy(attachable.fetch(:io))
      when ActiveStorage::Blob, String
        strip_stored_blob
      else
        super
      end
    end

    private

      def strip_metadata_on_upload?
        !::ImageMetadataStripper.internal_record?(record) && ::ImageMetadataStripper.strippable?(blob)
      end

      def keep_metadata?(path)
        record.respond_to?(:keep_attachment_metadata?) && record.keep_attachment_metadata?(name, path)
      end

      def upload_from_copy(io)
        file = ::ImageMetadataStripper.copy_to_tempfile(io)
        io.rewind if io.respond_to?(:rewind)

        ::ImageMetadataStripper.upload_stripped(blob, file.path, keep_ai_marker: keep_metadata?(file.path))
      rescue ::ImageMetadataStripper::StripFailedError => e
        ::ImageMetadataStripper.report_failure(blob, e)
        ::ImageMetadataStripper.upload_file(blob, file.path)
      ensure
        file&.close!
      end

      def strip_stored_blob
        return if record.attachment_changes.key?(name)
        return if ::ImageMetadataStripper.stripped?(blob)

        keep_ai_marker = keep_metadata?(nil) || ::ImageMetadataStripper.exempt_blob?(blob)
        ::ImageMetadataStripper.strip_stored!(blob, keep_ai_marker: keep_ai_marker)
      rescue StandardError => e
        ::ImageMetadataStripper.report_failure(blob, e)
      end
  end
end
