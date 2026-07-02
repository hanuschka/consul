module CsvServices
  class FormularAnswersExporter < CsvServices::BaseService
    require "csv"

    def initialize(formular, host = nil)
      @formular = formular
      @host = host
      @formular_answers = @formular.formular_answers
        .preload(
          formular_answer_images: { attachment_attachment: :blob },
          formular_answer_documents: { attachment_attachment: :blob }
        )
    end

    def call
      CSV.generate(headers: true, col_sep: ";", force_quotes: true, encoding: "UTF-8") do |csv|
        csv << headers

        @formular_answers.each do |formular_answer|
          csv << row(formular_answer)
        end
      end
    end

    private

      def headers
        @formular.formular_fields.map(&:name) + ["Submitter ID", "Submitter Email", "Submitted At"]
      end

      def row(formular_answer)
        @formular.formular_fields.map do |formular_field|
          case formular_field.kind
          when "image"
            attachment_links(formular_answer.formular_answer_images, formular_field, "inline")
          when "document"
            attachment_links(formular_answer.formular_answer_documents, formular_field, "attachment")
          else
            sanitize_for_csv(formular_answer.answers[formular_field.key])
          end
        end + [formular_answer.submitter_id, sanitize_for_csv(formular_answer.original_submitter_email), formular_answer.created_at]
      end

      def attachment_links(records, formular_field, disposition)
        records
          .select { |record| record.formular_field_key == formular_field.key && record.attachment.attached? }
          .map { |record| blob_url(record.attachment, disposition) }
          .join("\n")
      end

      def blob_url(attachment, disposition)
        path = Rails.application.routes.url_helpers.rails_blob_path(attachment, disposition: disposition, only_path: true)
        @host.present? ? "#{@host}#{path}" : path
      end
  end
end
