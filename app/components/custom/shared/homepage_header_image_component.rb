# frozen_string_literal: true

class Shared::HomepageHeaderImageComponent < ApplicationComponent
  DESKTOP_WIDTHS = [960, 1440, 1920, 2880, 3840].freeze
  MOBILE_WIDTHS = [480, 720, 1080, 1440, 2160, 2880, 3840].freeze
  DESKTOP_BOX_HEIGHT = 700
  DESKTOP_BOX_MAX_WIDTH = 1920
  MOBILE_BOX_HEIGHT = 640
  MOBILE_MAX_VIEWPORT = 750
  MOBILE_MEDIA = "(max-width: #{MOBILE_MAX_VIEWPORT}px)".freeze
  QUALITY = 90
  TRANSPARENT_PIXEL = "data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7"

  attr_reader :desktop_attachment, :mobile_attachment

  def initialize(desktop_attachment:, mobile_attachment: nil)
    @desktop_attachment = desktop_attachment if desktop_attachment&.attached?
    @mobile_attachment = mobile_attachment&.attached? ? mobile_attachment : @desktop_attachment
  end

  def render?
    !mobile_attachment.nil?
  end

  def desktop_srcset
    srcset(desktop_attachment, DESKTOP_WIDTHS)
  end

  def desktop_sizes
    width = cover_width(desktop_attachment, DESKTOP_BOX_HEIGHT)
    return "#{DESKTOP_BOX_MAX_WIDTH}px" if width.nil?
    return "#{width}px" if width >= DESKTOP_BOX_MAX_WIDTH

    "(min-width: #{DESKTOP_BOX_MAX_WIDTH}px) #{DESKTOP_BOX_MAX_WIDTH}px, (min-width: #{width}px) 100vw, #{width}px"
  end

  def desktop_src
    widths = candidate_widths(desktop_attachment, DESKTOP_WIDTHS)
    variant_path(desktop_attachment, widths.select { |w| w <= DESKTOP_BOX_MAX_WIDTH }.max || widths.min)
  end

  def mobile_srcset
    srcset(mobile_attachment, MOBILE_WIDTHS)
  end

  def mobile_sizes
    width = cover_width(mobile_attachment, MOBILE_BOX_HEIGHT)
    return "#{MOBILE_MAX_VIEWPORT}px" if width.nil?
    return "#{width}px" if width >= MOBILE_MAX_VIEWPORT

    "(min-width: #{width}px) 100vw, #{width}px"
  end

  private

    def srcset(attachment, widths)
      candidate_widths(attachment, widths).map { |w| "#{variant_path(attachment, w)} #{w}w" }.join(", ")
    end

    def candidate_widths(attachment, widths)
      original_width = attachment.blob.metadata["width"]
      return widths if original_width.blank?

      (widths.select { |w| w < original_width } + [[original_width, widths.max].min]).uniq
    end

    def cover_width(attachment, box_height)
      width, height = attachment.blob.metadata.values_at("width", "height")
      return if width.blank? || height.blank? || height.zero?

      (box_height * width.to_f / height).ceil
    end

    def variant_path(attachment, width)
      polymorphic_path(
        attachment.variant(
          resize_to_limit: [width, nil],
          saver: { quality: QUALITY },
          strip: true,
          format: :jpeg
        )
      )
    end
end
