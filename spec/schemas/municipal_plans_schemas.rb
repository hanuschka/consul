# frozen_string_literal: true

module Schemas
  module MunicipalPlans
    TRANSLATED_ATTRIBUTES = %w[
      title short_description further_information last_resolution processing_status next_steps
      costs formal_participation_reason informal_participation_reason contact_role
    ].freeze

    MAP_LOCATION_SCHEMA = Schemas::Miscellaneous::MAP_LOCATION_SCHEMA.merge(
      description: 'Location of the Vorhaben; null for a Vorhaben for the whole city.',
      properties: Schemas::Miscellaneous::MAP_LOCATION_SCHEMA[:properties].merge(
        latitude: { type: :number, format: :float, description: 'Latitude of the pin the public map shows: the first point of features, or the stored point when features has none', example: 50.9271 },
        longitude: { type: :number, format: :float, description: 'Longitude of the pin the public map shows: the first point of features, or the stored point when features has none', example: 11.5892 },
        address: { type: :string, nullable: true, description: 'Same as approximated_address; kept for existing clients', example: 'Eichplatz, Jena' }
      )
    ).freeze

    MUNICIPAL_PLAN_SCHEMA = {
      type: :object,
      properties: {
        id: { type: :integer, example: 12 },
        status: { type: :string, enum: %w[draft published archived], description: 'Read-only clients only get published Vorhaben (archived ones too with changed_since)', example: 'published' },
        version: { type: :string, description: 'Versionsnummer, set by the system', example: '1.3' },
        content_updated_at: { type: :string, format: :date, nullable: true, description: 'Day the content last changed', example: '2026-10-02' },
        last_public_change_at: { type: :string, format: :date_time, nullable: true, description: 'Last release, archiving or re-activation' },
        given_order: { type: :integer, nullable: true, description: 'Position in the editorial order of the Vorhabenliste (lower first); change it with PATCH /api/municipal_plans/order', example: 3 },
        city_wide: { type: :boolean, description: 'The Vorhaben concerns the whole city instead of single Ortsteile', example: false },
        formal_participation: { type: :boolean, example: true },
        informal_participation: { type: :boolean, example: false },
        contact_name: { type: :string, nullable: true, example: 'Kai Ostermann' },
        contact_phone: { type: :string, nullable: true, example: '03641 49-0' },
        contact_email: { type: :string, nullable: true, example: 'stadtplanung@jena.example' },
        **TRANSLATED_ATTRIBUTES.to_h { [it.to_sym, { type: :string, nullable: true, description: 'In the current language' }] },
        translations: Schemas::Miscellaneous.translations_schema(TRANSLATED_ATTRIBUTES),
        procedure_step: {
          type: :object, nullable: true,
          description: 'Verfahrensschritt from the list the instance maintains, with its name as entered there, null when none is set',
          properties: { id: { type: :integer }, name: { type: :string } },
          additionalProperties: false
        },
        districts: {
          type: :array,
          items: { type: :object, properties: { id: { type: :integer }, name: { type: :string } }, additionalProperties: false }
        },
        topics: {
          type: :array,
          items: { type: :object, properties: { id: { type: :integer }, name: { type: :string, nullable: true } }, additionalProperties: false }
        },
        links: {
          type: :array,
          items: { type: :object, properties: { title: { type: :string, nullable: true }, url: { type: :string, nullable: true } }, additionalProperties: false }
        },
        map_location: { '$ref' => '#/components/schemas/MunicipalPlanMapLocation' },
        projekts: {
          type: :array,
          description: 'Linked projekts that are publicly visible',
          items: {
            type: :object,
            properties: { id: { type: :integer }, title: { type: :string, nullable: true }, slug: { type: :string, nullable: true } },
            additionalProperties: false
          }
        },
        archive_on: { type: :string, format: :date, nullable: true, description: 'Planned Archivdatum. Only returned to admin clients.', example: '2027-03-31' },
        released_at: { type: :string, format: :date_time, nullable: true, description: 'Last release. Only returned to admin clients.' },
        responsible: {
          type: :object,
          nullable: true,
          description: 'Officer or officer group in charge. Only returned to admin clients.',
          properties: {
            id: { type: :integer },
            type: { type: :string, enum: ['MunicipalPlan::Officer', 'MunicipalPlan::OfficerGroup'] },
            name: { type: :string, nullable: true }
          },
          additionalProperties: false
        },
        notices_count: { type: :integer, description: 'Number of notices citizens sent about the Vorhaben; the notices themselves are never returned. Only returned to admin clients.', example: 2 },
        pending_working_copy: { type: :boolean, description: 'A change prepared in /adm waits for release; content writes are refused until it is released or discarded. Only returned to admin clients.', example: false }
      },
      required: %w[id status version translations districts topics links projekts],
      additionalProperties: false
    }.freeze

    MUNICIPAL_PLAN_WRITE_PARAMS = {
      type: :object,
      properties: {
        municipal_plan: {
          type: :object,
          description: 'Content of the Vorhaben. Every write is released right away, as a new version (see version); a Vorhaben still in Entwurf stays an Entwurf. The release checks what /adm checks: short description, processing status, next steps, responsible, location (unless city_wide), Ortsteile and Themen.',
          properties: {
            **TRANSLATED_ATTRIBUTES.to_h { [it.to_sym, { type: :string, description: 'In the current language' }] },
            translations: Schemas::Miscellaneous.translations_schema(TRANSLATED_ATTRIBUTES),
            city_wide: { type: :boolean },
            procedure_step_id: { type: :integer, nullable: true, description: 'ID of a Verfahrensschritt' },
            formal_participation: { type: :boolean },
            informal_participation: { type: :boolean },
            contact_name: { type: :string, nullable: true },
            contact_phone: { type: :string, nullable: true },
            contact_email: { type: :string, nullable: true },
            district_ids: { type: :array, items: { type: :integer }, description: 'Registered-address districts (at most 4; none when city_wide)' },
            topic_ids: { type: :array, items: { type: :integer }, description: 'IDs from GET /api/municipal_plan_topics' },
            links: {
              type: :array,
              description: 'The complete list of links; it replaces the links there were',
              items: { type: :object, properties: { title: { type: :string }, url: { type: :string } } }
            },
            responsible_type: { type: :string, enum: ['MunicipalPlan::Officer', 'MunicipalPlan::OfficerGroup'], description: 'Type of the officer or officer group in charge; send together with responsible_id' },
            responsible_id: { type: :integer },
            map_location_attributes: { '$ref' => '#/components/schemas/MapLocationWriteParams' },
            archive_on: { type: :string, format: :date, nullable: true, description: 'Planned Archivdatum. Written on the released Vorhaben without a new version; sent alone it releases nothing.' }
          }
        }
      },
      required: ['municipal_plan']
    }.freeze

    def self.all
      {
        MunicipalPlan: MUNICIPAL_PLAN_SCHEMA,
        MunicipalPlanMapLocation: MAP_LOCATION_SCHEMA,
        MunicipalPlanWriteParams: MUNICIPAL_PLAN_WRITE_PARAMS
      }
    end
  end
end
