class Masterportal::ImportService < ApplicationService
  MAX_FEATURES_PER_RUN = 20_000
  PROGRESS_FLUSH_EVERY = 5

  PHASE_TO_BUILDER = {
    "ProjektPhase::ProposalPhase" => Masterportal::Converters::ProposalBuilder,
    "ProjektPhase::BudgetPhase" => Masterportal::Converters::BudgetInvestmentBuilder,
    "ProjektPhase::PointOfInterestPhase" => Masterportal::Converters::PointOfInterestPinBuilder
  }.freeze

  CATEGORY_PHASE_TYPES = %w[
    ProjektPhase::ProposalPhase
    ProjektPhase::BudgetPhase
  ].freeze

  def initialize(
    projekt_phase:,
    endpoint_url:,
    collection_ids:,
    create_domain_records: false,
    triggered_by_user: nil
  )
    @projekt_phase = projekt_phase
    @endpoint_url = endpoint_url
    @collection_ids = Array(collection_ids)
    @create_domain_records = create_domain_records
    @triggered_by_user = triggered_by_user
    @stats = { imported: 0, updated: 0, skipped: 0, failed: 0, errors: [] }
    @projekt_labels_by_name = {}
  end

  def call
    return idempotency_error if already_running?

    start_import!

    @collection_titles = fetch_collection_titles

    @collection_ids.each do |collection_id|
      process_collection(collection_id)
    end

    finalize_success!
    @stats
  rescue => e
    Sentry.capture_exception(e) if defined?(Sentry)
    finalize_failure!(e)
    raise
  end

  private

    def already_running?
      @projekt_phase.reload.masterportal_import_status == "running"
    end

    def idempotency_error
      @stats[:errors] << "already_running"
      @stats
    end

    def start_import!
      @projekt_phase.update!(
        masterportal_import_status: "running",
        masterportal_last_endpoint_url: @endpoint_url,
        masterportal_last_collection_ids: @collection_ids.join(","),
        masterportal_last_imported_count: 0,
        masterportal_import_error: nil
      )
    end

    def flush_progress!
      processed = @stats[:imported] + @stats[:updated]
      @projekt_phase.update_column(:masterportal_last_imported_count, processed)
    end

    def process_collection(collection_id)
      count = 0

      OgcApiFeatures::Client.fetch_features(@endpoint_url, collection_id) do |feature|
        count += 1

        if count > MAX_FEATURES_PER_RUN
          raise "Collection #{collection_id} exceeds MAX_FEATURES_PER_RUN"
        end

        process_feature(feature: feature, collection_id: collection_id)
      end
    end

    def process_feature(feature:, collection_id:)
      if !point_geometry?(feature)
        @stats[:skipped] += 1
        return
      end

      report_out_of_bbox(feature)

      ActiveRecord::Base.transaction do
        was_new_record, pin = persist_pin(feature: feature, collection_id: collection_id)

        if @create_domain_records && pin.associated_record.nil?
          persist_domain_record(pin)
        end

        if was_new_record
          @stats[:imported] += 1
        else
          @stats[:updated] += 1
        end
      end

      processed = @stats[:imported] + @stats[:updated]
      flush_progress! if (processed % PROGRESS_FLUSH_EVERY).zero?
    rescue => e
      @stats[:failed] += 1
      @stats[:errors] << { feature_id: feature["id"], error: e.message }
      Sentry.capture_exception(e) if defined?(Sentry)
    end

    def persist_pin(feature:, collection_id:)
      pin = Masterportal::PinBuilder.call(
        projekt_phase: @projekt_phase,
        endpoint_url: @endpoint_url,
        collection_id: collection_id,
        collection_title: collection_titles[collection_id],
        feature: feature
      )
      was_new = pin.new_record?
      pin.save!

      [was_new, pin]
    end

    def persist_domain_record(pin)
      builder = PHASE_TO_BUILDER[@projekt_phase.type]
      return if builder.nil?

      record = builder.call(masterportal_pin: pin)
      assign_label(record, pin)
      record.save!
    end

    def assign_label(record, pin)
      return if CATEGORY_PHASE_TYPES.exclude?(@projekt_phase.type)

      Masterportal::LabelAssigner.call(
        record: record,
        pin: pin,
        labels_by_name: @projekt_labels_by_name
      )
    end

    def collection_titles
      @collection_titles || {}
    end

    def fetch_collection_titles
      collections = OgcApiFeatures::Client.list_collections(@endpoint_url)

      collections.each_with_object({}) do |collection, titles|
        titles[collection[:id]] = collection[:title]
      end
    rescue => e
      Sentry.capture_exception(e) if defined?(Sentry)
      {}
    end

    def point_geometry?(feature)
      feature.dig("geometry", "type") == "Point"
    end

    def report_out_of_bbox(feature)
      return if Masterportal::FeaturePropertyReader.inside_regensburg_bbox?(feature)
      return if !defined?(Sentry)

      Sentry.capture_message(
        "Masterportal feature outside Regensburg bbox",
        level: :warning,
        extra: {
          feature_id: feature["id"],
          projekt_phase_id: @projekt_phase.id,
          endpoint_url: @endpoint_url
        }
      )
    end

    def finalize_success!
      @projekt_phase.update!(
        masterportal_import_status: "success",
        masterportal_last_imported_at: Time.current,
        masterportal_last_imported_count: @stats[:imported] + @stats[:updated]
      )
    end

    def finalize_failure!(error)
      @projekt_phase.update!(
        masterportal_import_status: "failed",
        masterportal_import_error: error.message.truncate(1000)
      )
    end
end
