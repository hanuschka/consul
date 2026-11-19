# frozen_string_literal: true

module Schemas
  module Miscellaneous
    ARGUMENT_SCHEMA = {
      type: :object,
      properties: {
        id: { type: :integer, description: 'Unique identifier for the argument', example: 1 },
        name: { type: :string, description: 'Name of the person making the argument', example: 'Erika Muster' },
        party: { type: :string, nullable: true, description: 'Party or organisation of the person', example: 'Bürgerliste' },
        position: { type: :string, nullable: true, description: 'Role or office of the person', example: 'Ratsmitglied' },
        note: { type: :string, nullable: true, description: 'The argument text', example: 'This project will reduce CO2 emissions by 20% annually' },
        pro: { type: :boolean, nullable: true, description: 'true for an argument in favour, false for one against', example: true },
        projekt_phase_id: { type: :integer, description: 'ID of the projekt phase this argument belongs to', example: 18 },
        projekt_phase: { '$ref' => '#/components/schemas/ProjektPhaseReference' },
        projekt: { '$ref' => '#/components/schemas/ProjektReference' },
        created_at: { type: :string, format: :date_time, description: 'Timestamp when the argument was created', example: '2024-01-22T13:00:00Z' },
        updated_at: { type: :string, format: :date_time, description: 'Timestamp when the argument was last modified', example: '2024-01-25T10:30:00Z' },
        image: { '$ref' => '#/components/schemas/ImageResponse' }
      },
      required: %w[id name projekt_phase_id created_at updated_at],
      additionalProperties: false
    }.freeze

    IFRAME_SCHEMA = {
      type: :object,
      description: 'The page an iframe phase embeds. url, width and height are settings of the phase and only present once set.',
      properties: {
        url: { type: :string, description: 'The http(s) URL the phase page embeds', example: 'https://example.com/map' },
        width: { type: :string, description: 'Width of the iframe in pixels, as stored', example: '1200' },
        height: { type: :string, description: 'Height of the iframe in pixels, as stored', example: '600' },
        projekt_phase: {
          type: :object,
          description: 'The iframe phase',
          properties: {
            id: { type: :integer, example: 8 },
            type: { type: :string, example: 'ProjektPhase::IframePhase' },
            title: { type: :string, nullable: true, description: 'Tab name of the phase', example: 'Karte' },
            projekt_id: { type: :integer, example: 2 },
            active: { type: :boolean, example: true },
            created_at: { type: :string, format: :date_time, example: '2024-01-16T09:00:00Z' },
            updated_at: { type: :string, format: :date_time, example: '2024-01-18T14:00:00Z' },
            projekt: {
              type: :object,
              properties: {
                id: { type: :integer, example: 2 },
                title: { type: :string, example: 'Neugestaltung Marktplatz' }
              }
            }
          },
          required: %w[id type projekt_id active],
          additionalProperties: false
        }
      },
      required: ['projekt_phase'],
      additionalProperties: false
    }.freeze

    PAGINATION_RESPONSE_SCHEMA = {
      type: :object,
      properties: {
        current_page: { type: :integer },
        total_pages: { type: :integer },
        total_count: { type: :integer },
        per_page: { type: :integer }
      }
    }.freeze

    NO_PAGINATION_RESPONSE_SCHEMA = {
      type: :object,
      description: 'Returned in place of pagination metadata when no pagination was applied (all matching records returned in a single response). Supply the page and/or per_page query parameters to paginate.',
      properties: {
        message: {
          type: :string,
          description: 'Help text stating that all records were returned without pagination and how to enable it.',
          example: "All matching records were returned in a single response without pagination. To paginate, supply the 'page' and/or 'per_page' query parameters (for example: ?page=1&per_page=20)."
        }
      },
      required: ['message']
    }.freeze

    IMAGE_RESPONSE_SCHEMA = {
      type: :object,
      nullable: true,
      description: 'Image associated with the resource',
      properties: {
        id: { type: :integer, description: 'Image ID', example: 1 },
        title: { type: :string, nullable: true, description: 'Image title or alt text', example: 'Cover Image' },
        credits: { type: :string, nullable: true, description: 'Image attribution or credits', example: 'Photo by John Doe' },
        ai_generated: { type: :boolean, description: 'True when the image was created or edited with AI. Drives the visible AI disclosure label on public pages.', example: false },
        url: { type: :string, description: 'Full URL to the image', example: 'https://example.com/uploads/image.jpg' },
        variants: {
          type: :object,
          nullable: true,
          description: "Pre-generated resized versions of the image, keyed by their target maximum width in pixels (plus 'original'). Each numeric key is a variant scaled to fit within that width: the width is the upper bound, height scales proportionally so the aspect ratio is preserved, and the image is never enlarged beyond its original size (a source narrower than the key yields the smaller source dimensions, not an upscaled image). Pick the key closest to (and at least as large as) the width you will render at. By default every version is returned. The projekts list (index) endpoint accepts an 'image_variant_versions' query parameter (comma-separated, e.g. '300,900') to restrict this object to specific versions and shrink the payload; in that case only the requested keys are present.",
          properties: {
            "150": { type: :string, nullable: true, description: 'Max 150px wide. Thumbnail (avatars, list rows, tight grids).', example: 'https://example.com/uploads/150.jpg' },
            "300": { type: :string, nullable: true, description: 'Max 300px wide. Small (card teasers, mobile inline images).', example: 'https://example.com/uploads/300.jpg' },
            "450": { type: :string, nullable: true, description: 'Max 450px wide. Medium (sidebar, two-column card images).', example: 'https://example.com/uploads/450.jpg' },
            "600": { type: :string, nullable: true, description: 'Max 600px wide. Medium-large (single-column body images).', example: 'https://example.com/uploads/600.jpg' },
            "900": { type: :string, nullable: true, description: 'Max 900px wide. Large (wide content area, retina cards).', example: 'https://example.com/uploads/900.jpg' },
            "1200": { type: :string, nullable: true, description: 'Max 1200px wide. Extra large (page headers, hero on desktop).', example: 'https://example.com/uploads/1200.jpg' },
            "1920": { type: :string, nullable: true, description: 'Max 1920px wide. Full-width Full HD (full-bleed banners, retina hero).', example: 'https://example.com/uploads/1920.jpg' },
            "original": { type: :string, nullable: true, description: 'The unmodified uploaded file at its original dimensions (no resizing). Largest payload; use only when the exact source is required.', example: 'https://example.com/uploads/original.jpg' }
          }
        }
      }
    }.freeze

    LEGISLATION_DRAFT_VERSION_SCHEMA = {
      type: :object,
      properties: {
        id: { type: :integer, description: 'Unique identifier for the text draft', example: 1 },
        legislation_process_id: { type: :integer, description: 'ID of the legislation process (one per text participation phase) this draft belongs to', example: 7 },
        title: { type: :string, description: 'Title of the draft version', example: 'Second draft after public feedback' },
        changelog: { type: :string, nullable: true, description: 'What changed compared to the previous draft version', example: 'Section 3 rewritten based on comments' },
        body: { type: :string, nullable: true, description: 'Full text of the draft in Markdown', example: "# Introduction\n\nThe draft text." },
        body_html: { type: :string, nullable: true, description: 'The draft text rendered to sanitized HTML, as shown on the public page', example: "<h1 id=\"introduction\">Introduction</h1>\n\n<p>The draft text.</p>" },
        translations: {
          type: :object,
          description: 'Title, changelog and body per language, keyed by locale (e.g. de, en)',
          additionalProperties: {
            type: :object,
            properties: {
              title: { type: :string, nullable: true },
              changelog: { type: :string, nullable: true },
              body: { type: :string, nullable: true }
            },
            additionalProperties: false
          }
        },
        status: { type: :string, enum: %w[draft published], description: 'Publication status. Clients with public_data access only receive published drafts.', example: 'published' },
        created_at: { type: :string, format: :date_time, description: 'Timestamp when the draft was created', example: '2024-03-01T09:00:00Z' },
        updated_at: { type: :string, format: :date_time, description: 'Timestamp when the draft was last modified', example: '2024-03-05T14:30:00Z' }
      },
      required: %w[id legislation_process_id title status created_at updated_at]
    }.freeze

    AUTHOR_SCHEMA = {
      type: :object,
      description: 'Author of a contribution, limited to the name the public site shows next to it. Real names and email addresses are never returned.',
      properties: {
        id: { type: :integer, description: 'ID of the user. Only returned to admin clients.', example: 15 },
        public_name: { type: :string, nullable: true, description: 'Name shown on the site next to the contribution: the organisation name or the username. Null when the author hid their activity.', example: 'Gartenfreunde e.V.' }
      },
      required: ['public_name']
    }.freeze

    MAP_LOCATION_SCHEMA = {
      type: :object,
      nullable: true,
      description: 'Where the resource is on the map: the point, the shapes and lines drawn on it, and how they are displayed.',
      properties: {
        id: { type: :integer, description: 'ID of the location. Send it back in map_location_attributes to update the location in place.', example: 12 },
        latitude: { type: :number, format: :float, description: 'Latitude of the point', example: 51.4818 },
        longitude: { type: :number, format: :float, description: 'Longitude of the point', example: 7.2162 },
        altitude: { type: :number, format: :float, nullable: true, description: 'Altitude of the point in metres (3D maps)', example: 102.5 },
        zoom: { type: :integer, description: 'Zoom level the map opens at', example: 15 },
        approximated_address: { type: :string, nullable: true, description: 'Address geocoded from the point. Read-only.', example: 'Rathausplatz 1, Bochum' },
        features: {
          type: :object,
          description: 'GeoJSON FeatureCollection with every point, line and polygon of the location. Feature properties carry display data such as feature_color.',
          example: {
            type: 'FeatureCollection',
            features: [{ type: 'Feature', geometry: { type: 'Polygon', coordinates: [[[7.21, 51.48], [7.22, 51.48], [7.22, 51.49], [7.21, 51.48]]] }, properties: {} }]
          }
        },
        pin_color: { type: :string, nullable: true, description: 'Colour of the pin as a hex code', example: '#004a83' },
        show_admin_shape: { type: :boolean, nullable: true, description: 'Whether the shape drawn by staff is shown on the map', example: false },
        rendering_library: { type: :string, enum: %w[leaflet mapbox virtualcity leaflet_plus_masterportal], description: 'Map library that renders the location', example: 'leaflet' },
        mapbox_style_id: { type: :string, nullable: true, description: 'Mapbox style used when rendering_library is mapbox', example: 'mapbox/streets-v12' }
      },
      required: %w[id latitude longitude zoom features],
      additionalProperties: false
    }.freeze

    MAP_LOCATION_WRITE_PARAMS = {
      type: :object,
      description: 'Location on the map. Send the id returned in map_location to update the existing location; without an id the existing location is updated as well. Set _destroy to remove it.',
      properties: {
        id: { type: :integer, description: 'ID of the existing location', example: 12 },
        latitude: { type: :number, format: :float, example: 51.4818 },
        longitude: { type: :number, format: :float, example: 7.2162 },
        altitude: { type: :number, format: :float, example: 102.5 },
        zoom: { type: :integer, example: 15 },
        features: {
          description: 'GeoJSON FeatureCollection with points, lines and polygons, as an object or as a JSON string',
          oneOf: [{ type: :object }, { type: :string }]
        },
        pin_color: { type: :string, description: 'Hex colour of the pin', example: '#004a83' },
        show_admin_shape: { type: :boolean, example: false },
        rendering_library: { type: :string, enum: %w[leaflet mapbox virtualcity leaflet_plus_masterportal], example: 'leaflet' },
        mapbox_style_id: { type: :string, example: 'mapbox/streets-v12' },
        _destroy: { type: :boolean, description: 'Remove the location', example: false }
      }
    }.freeze

    # Every language of a translated resource, keyed by locale. Responses list
    # each stored language; request bodies may send any subset, and only the
    # attributes sent are changed.
    def self.translations_schema(attribute_names, read_only: [])
      writable_note =
        if read_only.any?
          " Read-only here: #{read_only.join(", ")}."
        else
          ""
        end

      {
        type: :object,
        description: "Texts per language, keyed by locale (e.g. de, en). Languages the instance doesn't offer are rejected.#{writable_note}",
        additionalProperties: {
          type: :object,
          properties: attribute_names.to_h { [it.to_sym, { type: :string, nullable: true }] },
          additionalProperties: false
        },
        example: {
          de: attribute_names.first(2).to_h { [it.to_sym, "Text (de)"] },
          en: attribute_names.first(2).to_h { [it.to_sym, "Text (en)"] }
        }
      }
    end

    EXTERNAL_REFERENCE_PROPERTIES = {
      external_source: { type: :string, nullable: true, description: 'System the record was synced from. Set by the client on create; "masterportal" for records imported from Masterportal.', example: 'stadtportal' },
      external_id: { type: :string, nullable: true, description: 'ID of the record in the external system, unique per source within its phase (budget for investments). Use it to sync without creating duplicates.', example: 'A-1042' }
    }.freeze

    EXTERNAL_REFERENCE_WRITE_PROPERTIES = {
      external_source: { type: :string, description: 'Name of the system the record comes from. Required together with external_id.', example: 'stadtportal' },
      external_id: { type: :string, description: 'ID of the record in that system. A second record with the same source and id in the same phase (budget for investments) is rejected with 422.', example: 'A-1042' }
    }.freeze

    def self.all
      {
        Argument: ARGUMENT_SCHEMA,
        Author: AUTHOR_SCHEMA,
        Iframe: IFRAME_SCHEMA,
        ImageResponse: IMAGE_RESPONSE_SCHEMA,
        LegislationDraftVersion: LEGISLATION_DRAFT_VERSION_SCHEMA,
        MapLocation: MAP_LOCATION_SCHEMA,
        MapLocationWriteParams: MAP_LOCATION_WRITE_PARAMS
      }
    end
  end
end
