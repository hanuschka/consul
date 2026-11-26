class Api::Configuration::VideosController < Api::Configuration::BaseController
  before_action :find_video_slot, only: [:update, :destroy]

  def index
    videos_by_name = SiteCustomization::Video.with_attached_video.index_by(&:name)
    video_slots = SiteCustomization::Video::VALID_VIDEOS.map do |name|
      serialize(videos_by_name[name] || SiteCustomization::Video.new(name:))
    end

    render json: { data: { videos: video_slots } }
  end

  def update
    previous_blob = @video_slot.persisted_video&.blob
    @video_slot.video = decoded_attachment(params.dig(:video, :attachment), @video_slot.name)

    if @video_slot.save
      audit_attachment_change(@video_slot, :video, previous_blob, @video_slot.video.blob)

      render json: { data: { video: serialize(@video_slot) } }
    else
      render_record_errors(@video_slot)
    end
  end

  def destroy
    previous_blob = @video_slot.persisted_video&.blob

    if previous_blob
      @video_slot.video.purge
      audit_attachment_change(@video_slot, :video, previous_blob, nil)
    end

    render json: { data: { video: serialize(@video_slot.reload) } }
  end

  private

    def find_video_slot
      if !SiteCustomization::Video::VALID_VIDEOS.include?(params[:name])
        raise ActiveRecord::RecordNotFound
      end

      @video_slot = SiteCustomization::Video.find_or_create_by!(name: params[:name])
    end

    def serialize(video_slot)
      {
        name: video_slot.name,
        allowed_content_types: SiteCustomization::Video::VALID_FORMATS,
        max_byte_size: SiteCustomization::Video::MAX_FILE_SIZE,
        video: serialize_attachment(video_slot.persisted_video)
      }
    end
end
