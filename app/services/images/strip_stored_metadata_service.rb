class Images::StripStoredMetadataService < ApplicationService
  Report = Struct.new(:stripped, :already_stripped, :exempt, :failed, keyword_init: true)

  class ExiftoolUnavailableError < StandardError; end

  PROGRESS_EVERY = 100
  DEFERRED_SIGNALS = %w[INT TERM HUP].freeze

  def initialize(logger: Rails.logger)
    @logger = logger
    @report = Report.new(stripped: 0, already_stripped: 0, exempt: 0, failed: 0)
  end

  def call
    if ::ExiftoolCommand.version.nil?
      raise ExiftoolUnavailableError, "exiftool cannot run from #{::ExiftoolCommand.binary_path.inspect}"
    end

    blobs = ActiveStorage::Blob.where(content_type: ::ImageMetadataStripper::CONTENT_TYPES)
    total = blobs.count

    blobs.find_each.with_index(1) do |blob, done|
      deferring_signals { process(blob) }
      yield @report, done, total if block_given? && (done % PROGRESS_EVERY).zero?
    end

    @logger.info("[Images::StripStoredMetadataService] #{@report.to_h}")

    @report
  end

  private

    def deferring_signals
      received = nil
      previous = DEFERRED_SIGNALS.to_h { |signal| [signal, Signal.trap(signal) { received ||= signal }] }

      yield
    ensure
      previous&.each { |signal, handler| Signal.trap(signal, handler || "DEFAULT") }
      Process.kill(received, Process.pid) if received
    end

    def process(blob)
      return @report.already_stripped += 1 if ::ImageMetadataStripper.stripped?(blob)

      exempt = ::ImageMetadataStripper.exempt_blob?(blob)
      ::ImageMetadataStripper.strip_stored!(blob, keep_ai_marker: exempt)

      if exempt
        @report.exempt += 1
      else
        @report.stripped += 1
      end
    rescue ActiveStorage::FileNotFoundError
      @report.failed += 1
      @logger.warn("[Images::StripStoredMetadataService] blob #{blob.id} has no file in storage")
    rescue StandardError => e
      @report.failed += 1
      ::ImageMetadataStripper.report_failure(blob, e)
    end
end
