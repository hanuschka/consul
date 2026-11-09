# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Configuration Map Layers API', type: :request, openapi_spec: 'v1/swagger.yaml' do
  let!(:api_client) { create_configuration_api_client }
  let(:Authorization) { "Bearer #{api_client.access_token}" }

  def create_global_map_layer(attributes = {})
    MapLayer.create!(
      {
        name: 'OpenStreetMap',
        provider: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
        attribution: '&copy; OpenStreetMap',
        protocol: 'regular',
        base: true,
        mappable: nil
      }.merge(attributes)
    )
  end

  templates_note = "Instance-wide layers are templates: every new projekt gets its own copies, so " \
                   "changing or deleting a layer here does not change existing projekts."

  map_layer_schema = {
    type: :object,
    properties: {
      id: { type: :integer, example: 1 },
      name: { type: :string, example: 'OpenStreetMap' },
      provider: { type: :string, nullable: true, example: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png' },
      attribution: { type: :string, nullable: true, description: 'Only links (`<a>`) are kept' },
      layer_names: { type: :string, nullable: true },
      protocol: { type: :string, enum: MapLayer.protocols.keys },
      base: { type: :boolean, nullable: true },
      show_by_default: { type: :boolean, nullable: true },
      transparent: { type: :boolean, nullable: true },
      opacity: { type: :number, nullable: true, minimum: 0, maximum: 1 },
      config: { type: :object, description: 'Style, popup and choropleth settings of GeoJSON layers' },
      geojson_file: {
        type: :object,
        nullable: true,
        properties: {
          url: { type: :string, format: :uri },
          filename: { type: :string },
          content_type: { type: :string },
          byte_size: { type: :integer }
        }
      },
      created_at: { type: :string, format: :date_time },
      updated_at: { type: :string, format: :date_time }
    },
    required: %w[id name protocol config]
  }

  map_layer_input_schema = {
    type: :object,
    properties: {
      map_layer: {
        type: :object,
        properties: {
          name: { type: :string, maxLength: 255 },
          provider: { type: :string, maxLength: 2048, description: 'http(s) tile or service URL' },
          attribution: { type: :string, maxLength: 1000 },
          layer_names: { type: :string, maxLength: 1000, description: 'WMS layer names' },
          protocol: { type: :string, enum: MapLayer.protocols.keys },
          base: { type: :boolean },
          show_by_default: { type: :boolean },
          transparent: { type: :boolean },
          opacity: { type: :number, minimum: 0, maximum: 1 },
          config: {
            type: :object,
            description: 'Replaces the whole config',
            properties: {
              label_property: { type: :string },
              popup_properties: { type: :array, items: { type: :string } },
              style: {
                type: :object,
                properties: {
                  fillColor: { type: :string },
                  fillOpacity: { type: :number },
                  color: { type: :string },
                  weight: { type: :number }
                }
              },
              choropleth: {
                type: :object,
                properties: {
                  enabled: { type: :boolean },
                  property: { type: :string },
                  legend_title: { type: :string },
                  no_data_color: { type: :string },
                  breaks: { type: :array, items: { type: :number } },
                  colors: { type: :array, items: { type: :string } }
                }
              }
            }
          },
          geojson_file: {
            type: :string,
            description: 'GeoJSON file base64 encoded, bare or as a data URI (max 20 MB); required for `geojson` layers'
          }
        }
      }
    },
    required: ['map_layer']
  }

  path '/api/configuration/map_layers' do
    get 'List instance-wide map layers' do
      tags 'Configuration Maps'
      produces 'application/json'
      security [bearer_auth: []]
      description "#{templates_note}#{ApiAccessRequirements::CONFIGURATION_REQUIRED}"
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number (**default:** 1)'
      parameter name: :per_page, in: :query, type: :integer, required: false,
                description: 'Layers per page (**default:** 500, max: 2000)'

      response '200', 'map layers listed' do
        let!(:global_layer) { create_global_map_layer }
        let!(:projekt_layer) { create_global_map_layer(name: 'Projekt layer', mappable: create(:projekt)) }

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: { map_layers: { type: :array, items: map_layer_schema } },
                   required: ['map_layers']
                 },
                 pagination: Schemas::Miscellaneous::PAGINATION_RESPONSE_SCHEMA
               }

        run_test! do |response|
          ids = JSON.parse(response.body)['data']['map_layers'].map { |map_layer| map_layer['id'] }

          expect(ids).to include(global_layer.id)
          expect(ids).not_to include(projekt_layer.id)
        end
      end

      unauthorized_response
      configuration_forbidden_response
    end

    post 'Create an instance-wide map layer' do
      tags 'Configuration Maps'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "#{templates_note}#{ApiAccessRequirements::CONFIGURATION_REQUIRED}"
      parameter name: :body, in: :body, required: true, schema: map_layer_input_schema

      response '201', 'map layer created' do
        let(:body) do
          {
            map_layer: {
              name: 'Stadtplan',
              provider: 'https://geo.example.org/wms',
              layer_names: 'stadtplan',
              protocol: 'wms',
              attribution: '<a href="https://example.org" onclick="steal()">Stadt</a><img src=x onerror=alert(1)>',
              transparent: true,
              opacity: 0.5
            }
          }
        end

        schema type: :object, properties: { data: { type: :object, properties: { map_layer: map_layer_schema } } }

        run_test! do |response|
          map_layer = MapLayer.find(JSON.parse(response.body)['data']['map_layer']['id'])

          expect(map_layer.mappable).to be_nil
          expect(map_layer.attribution).to eq('<a href="https://example.org">Stadt</a>')
          expect(map_layer.opacity.to_f).to eq(0.5)
          expect(map_layer.audits.last.action).to eq('create')
          expect(map_layer.audits.last.comment).to eq("api_client:#{api_client.id}")
          expect(map_layer.audits.last.user).to eq(api_client.content_author)
        end
      end

      response '201', 'GeoJSON layer created with its file' do
        let(:geojson) { { type: 'FeatureCollection', features: [] }.to_json }
        let(:body) do
          {
            map_layer: {
              name: 'Spielplätze',
              protocol: 'geojson',
              geojson_file: "data:application/json;base64,#{Base64.strict_encode64(geojson)}",
              config: { label_property: 'name', popup_properties: %w[name address] }
            }
          }
        end

        run_test! do |response|
          map_layer = MapLayer.find(JSON.parse(response.body)['data']['map_layer']['id'])

          expect(map_layer.geojson_file).to be_attached
          expect(map_layer.config['popup_properties']).to eq(%w[name address])
          expect(Audit.where(auditable: map_layer).pluck(:audited_changes).map(&:keys).flatten).to include('geojson_file')
        end
      end

      response '422', 'invalid values' do
        let(:body) { { map_layer: { name: '', protocol: 'ftp', opacity: 3, provider: 'javascript:alert(1)' } } }

        schema '$ref' => '#/components/schemas/ConfigurationValidationError'

        run_test! do |response|
          details = JSON.parse(response.body)['error']['details']

          expect(details.keys).to match_array(%w[name protocol opacity provider])
          expect(MapLayer.where(provider: 'javascript:alert(1)')).to be_empty
        end
      end

      response '422', 'GeoJSON layer without a file' do
        let(:body) { { map_layer: { name: 'Leer', protocol: 'geojson' } } }

        schema '$ref' => '#/components/schemas/ConfigurationValidationError'

        run_test!
      end

      unauthorized_response
      configuration_forbidden_response
    end
  end

  path '/api/configuration/map_layers/{id}' do
    parameter name: :id, in: :path, type: :integer, required: true

    get 'Show an instance-wide map layer' do
      tags 'Configuration Maps'
      produces 'application/json'
      security [bearer_auth: []]
      description "#{templates_note}#{ApiAccessRequirements::CONFIGURATION_REQUIRED}"

      response '200', 'map layer found' do
        let(:id) { create_global_map_layer.id }

        schema type: :object, properties: { data: { type: :object, properties: { map_layer: map_layer_schema } } }

        run_test!
      end

      response '404', 'projekt layers are not instance-wide' do
        let(:id) { create_global_map_layer(mappable: create(:projekt)).id }

        run_test!
      end

      unauthorized_response { let(:id) { create_global_map_layer.id } }
      configuration_forbidden_response { let(:id) { create_global_map_layer.id } }
    end

    patch 'Change an instance-wide map layer' do
      tags 'Configuration Maps'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Only the attributes sent are changed. #{templates_note}" \
                  "#{ApiAccessRequirements::CONFIGURATION_REQUIRED}"
      parameter name: :body, in: :body, required: true, schema: map_layer_input_schema

      response '200', 'map layer changed' do
        let(:map_layer) { create_global_map_layer }
        let(:id) { map_layer.id }
        let(:body) { { map_layer: { name: 'Basiskarte', show_by_default: true } } }

        schema type: :object, properties: { data: { type: :object, properties: { map_layer: map_layer_schema } } }

        run_test! do
          map_layer.reload
          audit = map_layer.audits.last

          expect(map_layer.name).to eq('Basiskarte')
          expect(map_layer.show_by_default).to be(true)
          expect(audit.audited_changes['name']).to eq(%w[OpenStreetMap Basiskarte])
          expect(audit.comment).to eq("api_client:#{api_client.id}")
        end
      end

      response '422', 'invalid opacity' do
        let(:id) { create_global_map_layer.id }
        let(:body) { { map_layer: { opacity: 'half' } } }

        schema '$ref' => '#/components/schemas/ConfigurationValidationError'

        run_test!
      end

      response '404', 'map layer not found' do
        let(:id) { 0 }
        let(:body) { { map_layer: { name: 'Basiskarte' } } }

        run_test!
      end

      unauthorized_response { let(:id) { create_global_map_layer.id } }
      configuration_forbidden_response { let(:id) { create_global_map_layer.id } }
    end

    delete 'Delete an instance-wide map layer' do
      tags 'Configuration Maps'
      produces 'application/json'
      security [bearer_auth: []]
      description "#{templates_note}#{ApiAccessRequirements::CONFIGURATION_REQUIRED}"

      response '200', 'map layer deleted' do
        let(:map_layer) { create_global_map_layer }
        let(:id) { map_layer.id }

        run_test! do
          expect(MapLayer.exists?(map_layer.id)).to be(false)
          expect(Audit.where(auditable_type: 'MapLayer', auditable_id: map_layer.id).last.action).to eq('destroy')
        end
      end

      response '404', 'map layer not found' do
        let(:id) { 0 }

        run_test!
      end

      unauthorized_response { let(:id) { create_global_map_layer.id } }
      configuration_forbidden_response { let(:id) { create_global_map_layer.id } }
    end
  end
end
