class Images::AuditAiMarkingService < ApplicationService
  # Answers, without changing anything, how many pictures this app generated are
  # published without the AI marker in their bytes. It is the read-only
  # counterpart to Images::BackfillAiMarkingService and shares its scope, so a
  # run says exactly what a backfill would repair.
  #
  # Worth having as its own service rather than a flag on the backfill: the state
  # it detects is silent by nature — the picture looks right on the page, the
  # record can even carry the flag, and only the bytes say otherwise. Nothing
  # reports it, which is how a broken attach path published unmarked pictures
  # unnoticed. Running this on an environment is how that is caught next time.
  #
  # Returns the affected image ids alongside the counts, since an audit whose
  # answer is "some" has to be able to name which.
  RESOURCE_CLASSES = Images::BackfillAiMarkingService::RESOURCE_CLASSES

  Report = Struct.new(:checked, :marked, :unmarked, :unreadable, :unmarked_ids, keyword_init: true)

  def initialize(logger: Rails.logger)
    @logger = logger
    @report = Report.new(checked: 0, marked: 0, unmarked: 0, unreadable: 0, unmarked_ids: [])
  end

  def call
    generated_images.find_each { |image| check(image) }

    @report
  end

  private

    # The same scope the backfill repairs: the resource's own column is the only
    # place a picture's origin was recorded, so an image whose flags were never
    # written is still found here.
    def generated_images
      conditions = RESOURCE_CLASSES.map do |resource_class|
        Image
          .where(imageable_type: resource_class.name)
          .where(imageable_id: resource_class.unscoped.where(generated_image: true).select(:id))
      end

      conditions.reduce { |scope, condition| scope.or(condition) }
    end

    def check(image)
      return if !image.attachment.attached?

      @report.checked += 1

      extension = File.extname(image.attachment.filename.to_s).presence || ".jpg"

      if ::Images::AiMarker.marker_in?(image.attachment.download, extension: extension)
        @report.marked += 1
      else
        @report.unmarked += 1
        @report.unmarked_ids << image.id
      end
    rescue StandardError => e
      @report.unreadable += 1

      @logger.error("[Images::AuditAiMarkingService] image #{image.id} unreadable: #{e.message}")
    end
end
