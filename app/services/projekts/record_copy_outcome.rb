# The one writer of `copy_status` and `copy_data`. A local copy and a
# cross-instance import reach it with results of the same shape, so the badge
# and the poller cannot drift between the two paths.
#
# `update_columns` rather than `update!`: the row is a half-built copy whose
# validations may not pass yet, and recording what happened to it must never be
# the thing that fails.
class Projekts::RecordCopyOutcome < ApplicationService
  def initialize(projekt:, result: nil, error: nil)
    @projekt = projekt
    @result = result
    @error = error
  end

  def call
    return if projekt.blank?

    projekt.update_columns(copy_status: status, copy_data: data.presence)
  end

  private

    attr_reader :projekt, :result, :error

    def status
      return "failed" if error.present? || result.blank?

      result.success? ? "completed" : "failed"
    end

    def data
      return { "error" => error_data } if error_data.present?

      skipped = Array(result&.skipped_blobs)
      return {} if skipped.empty?

      { "skipped_blobs" => skipped }
    end

    # An exception the job caught outright, a reason the job knows without one
    # (an unreachable source), or a failure the runner already turned into a
    # message -- either way the admin needs the reason, not just the badge.
    def error_data
      return { "class" => error.class.name, "message" => error.message } if error.is_a?(Exception)
      return { "message" => error.to_s } if error.present?
      return if result.blank? || result.success?

      { "class" => result.error_details[:class], "message" => result.error }.compact
    end
end
