module HasEmbeddableShortcodes
  extend ActiveSupport::Concern

  SUPPORTED_SHORTCODES = %w[projekt_map].freeze

  PHASE_RESOURCE_SOURCES = {
    "proposals" => {
      source: "proposal_phase",
      process: "proposals",
      phase_type: "ProjektPhase::ProposalPhase"
    },
    "investments" => {
      source: "budget_phase",
      process: "investments",
      phase_type: "ProjektPhase::BudgetPhase"
    },
    "points_of_interest" => {
      source: "point_of_interest_phase",
      process: "point_of_interest_pins",
      phase_type: "ProjektPhase::PointOfInterestPhase"
    }
  }.freeze

  def process_shortcodes(text, **vars)
    return text if text.blank?

    text.scan(/{{(.*?)}}/).each do |shortcode|
      name = shortcode.first
      next if SUPPORTED_SHORTCODES.exclude?(name)

      text = replace_shortcode(name, text, **vars)
    end

    text
  end

  def render_map_embed_shortcode(resource:, phase_id:, projekt:)
    context = view_render_context
    component = map_component_for(resource, phase_id, projekt, SecureRandom.hex(4))

    context.content_tag(:div, class: "projekt-map-shortcode") do
      component.render_in(context)
    end
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

      if text.include?("js-projekt-map-embed")
        replace_map_embeds(text, projekt)
      else
        replace_bare_map_tokens(text, projekt)
      end
    end

    # gsub with a block so each occurrence renders with a unique DOM id;
    # duplicate ids would break App.Map init (getElementById) when several
    # map embeds share a page.
    def replace_bare_map_tokens(text, projekt)
      text.gsub("{{projekt_map}}") do
        render_map_embed_shortcode(resource: nil, phase_id: nil, projekt: projekt)
      end
    end

    # Wrapper-aware replacement: each .js-projekt-map-embed carries the
    # persisted resource/phase choice as data attributes, so its inner
    # {{projekt_map}} token renders the selected map instead of the default.
    def replace_map_embeds(text, projekt)
      fragment = Nokogiri::HTML::DocumentFragment.parse(text)

      fragment.css(".js-projekt-map-embed").each do |embed|
        resource = embed["data-map-resource"]
        phase_id = embed["data-map-phase-id"]

        embed.xpath(".//text()").each do |node|
          next if node.content.exclude?("{{projekt_map}}")

          rendered = node.content.gsub("{{projekt_map}}") do
            render_map_embed_shortcode(resource: resource, phase_id: phase_id, projekt: projekt)
          end

          node.replace(rendered)
        end
      end

      replace_bare_map_tokens(fragment.to_html, projekt)
    end

    def map_component_for(resource, phase_id, projekt, instance_suffix)
      phase_source = PHASE_RESOURCE_SOURCES[resource.to_s]

      if resource.to_s == "projekts"
        all_projekts_map_component(instance_suffix: instance_suffix)
      elsif phase_source.present? && projekt.present?
        phase_resource_map_component(phase_source, phase_id, projekt, instance_suffix)
      elsif projekt.present?
        projekt_map_component(projekt, instance_suffix: instance_suffix)
      else
        all_projekts_map_component(instance_suffix: instance_suffix)
      end
    end

    def projekt_map_component(projekt, instance_suffix: nil)
      Shared::MapComponent.new(
        mappable: projekt,
        features: projekt_location_features(projekt),
        process: "projekts",
        instance_suffix: instance_suffix
      )
    end

    def projekt_location_features(projekt)
      location = projekt.map_location

      return [] if location.blank?
      return [] if location.latitude.blank? || location.longitude.blank?

      [location.json_data]
    end

    def phase_resource_map_component(phase_source, phase_id, projekt, instance_suffix)
      phase_ids = resource_phase_ids(phase_source, phase_id, projekt)

      if phase_ids.blank?
        return Shared::MapComponent.new(
          mappable: projekt,
          features: [],
          process: phase_source[:process],
          instance_suffix: instance_suffix
        )
      end

      map_data_url =
        view_render_context.map_data_path(
          **map_data_url_params(phase_source[:source], phase_ids)
        )

      Shared::MapComponent.new(
        mappable: projekt,
        process: phase_source[:process],
        map_data_url: map_data_url,
        lazy_load_threshold: -1,
        instance_suffix: instance_suffix
      )
    end

    # A pinned phase id is validated against the same visibility rules as the
    # "all phases" aggregation, so a phase hidden after being selected renders
    # an empty map instead of leaking its resources.
    def resource_phase_ids(phase_source, phase_id, projekt)
      phases = visible_resource_phases(projekt, phase_source)

      if phase_id.present? && phase_id != "all"
        phases = phases.where(id: phase_id)
      end

      phases.includes(:settings).select(&:resource_map_enabled?).map(&:id)
    end

    # Mirrors Pages::Projekts::FooterPhasesComponent: regular visitors only see
    # active + frontend-visible phases; admins/PMs see all phases of the type.
    def visible_resource_phases(projekt, phase_source)
      phases = projekt.projekt_phases.where(type: phase_source[:phase_type])

      if view_render_context.show_admin_controls_for_projekt?(projekt)
        phases
      else
        phases.active.frontend_visible
      end
    end

    def map_data_url_params(source, phase_ids)
      if phase_ids.size == 1
        { source: source, projekt_phase_id: phase_ids.first }
      else
        { source: source, projekt_phase_ids: phase_ids.join(",") }
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
