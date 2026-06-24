module HasEmbeddableShortcodes
  extend ActiveSupport::Concern

  SUPPORTED_SHORTCODES = %w[projekt_map].freeze

  def process_shortcodes(text, **vars)
    return text if text.blank?

    text.scan(/{{(.*?)}}/).each do |shortcode|
      name = shortcode.first
      next if SUPPORTED_SHORTCODES.exclude?(name)

      text = replace_shortcode(name, text, **vars)
    end

    text
  end

  private

    def replace_shortcode(name, text, **vars)
      case name
      when "projekt_map"
        replace_projekt_map(text, **vars)
      else
        text
      end
    end

    def replace_projekt_map(text, **vars)
      projekt = vars[:projekt]
      return text if projekt.blank?

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
