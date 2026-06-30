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
      context = view_render_context

      # gsub with a block so each occurrence renders with a unique DOM id;
      # duplicate ids would break App.Map init (getElementById) when several
      # map embeds share a page.
      text.gsub("{{projekt_map}}") do
        instance_suffix = SecureRandom.hex(4)

        component =
          if projekt.present?
            projekt_map_component(projekt, instance_suffix: instance_suffix)
          else
            all_projekts_map_component(instance_suffix: instance_suffix)
          end

        context.content_tag(:div, class: "projekt-map-shortcode") do
          component.render_in(context)
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

    # No projekt context (e.g. the homepage): render the city-wide overview map
    # with every visible projekt as a pin, mirroring the projekts overview page.
    def all_projekts_map_component(instance_suffix: nil)
      Shared::MapComponent.new(
        features: all_projekts_overview_coordinates,
        process: "projekts",
        instance_suffix: instance_suffix
      )
    end

    # Runs on every homepage hit. Two optimizations keep it cheap at scale:
    #   * anonymous visitors (the bulk of homepage traffic) all see the same
    #     public set, so their coordinates are cached;
    #   * pins are built straight from plucked columns — no MapLocation/Projekt
    #     AR objects are instantiated. Projekt pins never carry a color/icon
    #     (MapLocation#get_feature_* only resolve those for Proposal/Investment/
    #     DeficiencyReport/Idea), so the per-record association reads behind
    #     json_data are pure overhead here.
    def all_projekts_overview_coordinates
      return projekts_overview_coordinates_for(current_user) if current_user.present?

      Rails.cache.fetch(projekts_overview_coordinates_cache_key, expires_in: 15.minutes) do
        projekts_overview_coordinates_for(nil)
      end
    end

    def projekts_overview_coordinates_for(user)
      projekt_ids = Projekt.visible_for(user).pluck(:id)

      MapLocation
        .where(mappable_type: "Projekt", mappable_id: projekt_ids, show_admin_shape: true)
        .pluck(:longitude, :latitude, :mappable_id)
        .map { |longitude, latitude, projekt_id| projekt_map_feature(longitude, latitude, projekt_id) }
    end

    def projekt_map_feature(longitude, latitude, projekt_id)
      {
        "type" => "FeatureCollection",
        "features" => [{
          "type" => "Feature",
          "geometry" => { "type" => "Point", "coordinates" => [longitude, latitude] },
          "properties" => {
            "resource_type" => MapLocation::RESOURCE_TYPE_MAPPING[:Projekt],
            "id" => projekt_id,
            "feature_color" => nil,
            "feature_icon_name" => nil,
            "feature_icon_unicode" => nil
          }
        }]
      }
    end

    # map_locations carries no timestamps, but `belongs_to :mappable, touch: true`
    # means creating/moving a location bumps its projekt's updated_at — so this
    # single cheap aggregate busts on projekt edits, new projekts, and moved
    # pins alike. The 15-minute TTL bounds staleness for visibility changes that
    # live in projekt_settings (e.g. publishing) and don't touch updated_at.
    def projekts_overview_coordinates_cache_key
      [
        "homepage_projekts_overview_coordinates",
        Projekt.regular.maximum(:updated_at).to_f
      ]
    end

    def view_render_context
      respond_to?(:view_context) ? view_context : self
    end
end
