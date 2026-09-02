# frozen_string_literal: true

module RuboCop
  module Cop
    module Consul
      # Generated images are marked as AI-generated with an IPTC metadata
      # field, and ImageMagick's `strip` discards it. `Image#attachment_variant`
      # is what decides between the two cases: it strips for an uploaded
      # photograph, whose camera EXIF carries GPS that must never be published,
      # and preserves for a generated one, whose marker is the thing that makes
      # it detectable.
      #
      # Reaching past it to the attachment picks neither rule. Depending on the
      # options passed, that silently publishes a visitor's coordinates or
      # silently ships an unmarked generated picture -- and neither shows up
      # until someone audits it.
      #
      # @example
      #   # bad
      #   image.attachment.variant(resize_to_limit: [500, 500], strip: true)
      #   image&.attachment&.variant(resize_to_limit: [500, 500])
      #
      #   # good
      #   image.attachment_variant(resize_to_limit: [500, 500])
      #   image&.attachment_variant(resize_to_limit: [500, 500])
      class ImageAttachmentVariant < Base
        MSG = "Use `Image#attachment_variant` instead of reaching for the " \
              "attachment: it decides whether metadata is stripped, which is " \
              "both the GPS protection for uploads and the AI marking for " \
              "generated images."

        RESTRICT_ON_SEND = %i[variant].freeze

        def_node_matcher :attachment_variant?, <<~PATTERN
          ({send csend} {(send _ :attachment) (csend _ :attachment)} :variant ...)
        PATTERN

        def on_send(node)
          return if !attachment_variant?(node)

          add_offense(node)
        end

        alias on_csend on_send
      end
    end
  end
end
