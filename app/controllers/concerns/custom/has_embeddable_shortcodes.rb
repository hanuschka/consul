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

      replacement = context.content_tag(:div, style: "margin-top:1rem;margin-bottom:1rem;") do
        projekt_map_component(projekt).render_in(context)
      end

      text.gsub("{{projekt_map}}", replacement)
    end

    def projekt_map_component(projekt)
      component_class = projekt.vc_map_enabled? ? Shared::VCMapComponent : Shared::MapComponent

      component_class.new(
        map_location: projekt.map_location,
        parent_class: "shortcode",
        projekt: projekt,
        show_admin_shape: projekt.map_location.show_admin_shape?
      )
    end

    def view_render_context
      respond_to?(:view_context) ? view_context : self
    end
end
