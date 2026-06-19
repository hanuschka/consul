module HasEmbeddableShortcodes
  extend ActiveSupport::Concern

  SUPPORTED_SHORTCODES = %w[projekt_map].freeze

  def process_shortcodes_for(obj:, attr:, **vars)
    text = obj.send(attr)

    text&.scan(/{{(.*?)}}/) do |shortcode|
      next unless SUPPORTED_SHORTCODES.include?(shortcode.first)

      text = send("replace_#{shortcode.first}", text, **vars)
    end

    text
  end

  private

    def replace_projekt_map(text, **vars)
      return unless vars[:projekt].present?

      projekt = vars[:projekt]

      context = view_render_context

      # gsub with a block so each occurrence renders with a unique DOM id;
      # duplicate ids would break App.Map init (getElementById) when several
      # map embeds share a page.
      text.gsub("{{projekt_map}}") do
        context.content_tag(:div, class: "projekt-map-shortcode") do
          projekt_map_component(projekt, instance_suffix: SecureRandom.hex(4)).render_in(context)
        end
      end
    end

    def projekt_map_component(projekt, instance_suffix: nil)
      if projekt.vc_map_enabled?
        Shared::VCMapComponent.new(
          map_location: projekt.map_location,
          parent_class: "shortcode",
          projekt: projekt,
          show_admin_shape: projekt.map_location.show_admin_shape?,
          instance_suffix: instance_suffix
        )
      else
        Shared::MapComponent.new(mappable: projekt, instance_suffix: instance_suffix)
      end
    end

    def view_render_context
      respond_to?(:view_context) ? view_context : self
    end
end
