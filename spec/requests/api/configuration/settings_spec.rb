# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Configuration Settings API', type: :request, openapi_spec: 'v1/swagger.yaml' do
  let!(:api_client) { create_configuration_api_client }
  let(:Authorization) { "Bearer #{api_client.access_token}" }

  path '/api/configuration/settings' do
    get 'List configurable settings' do
      tags 'Configuration Settings'
      produces 'application/json'
      security [bearer_auth: []]
      description "Every instance setting the API may change, with its type, allowed options " \
                  "and current value. Keys not listed here cannot be changed through the API." \
                  "#{ApiAccessRequirements::CONFIGURATION_REQUIRED}"
      parameter name: :group, in: :query, required: false,
                schema: { type: :string, enum: Setting::ConfigurableKeys::GROUPS },
                description: 'Only list the settings of one group'

      response '200', 'settings listed' do
        before { Setting["brand_color"] = "#123456" }

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     settings: { type: :array, items: { '$ref' => '#/components/schemas/ConfigurationSettingEntry' } }
                   },
                   required: ['settings']
                 }
               },
               required: ['data']

        run_test! do |response|
          settings = JSON.parse(response.body)['data']['settings']
          brand_color = settings.find { |setting| setting['key'] == 'brand_color' }

          expect(settings.map { |setting| setting['key'] }).to match_array(Setting::ConfigurableKeys.all.keys)
          expect(brand_color).to include('type' => 'color', 'group' => 'branding', 'value' => '#123456')
        end
      end

      response '200', 'settings of one group listed' do
        let(:group) { 'metadata' }

        run_test! do |response|
          groups = JSON.parse(response.body)['data']['settings'].map { |setting| setting['group'] }

          expect(groups.uniq).to eq(['metadata'])
        end
      end

      unauthorized_response
      configuration_forbidden_response

      response '403', 'forbidden - internal API client tokens cannot configure the instance' do
        let(:internal_client) { InternalApiClient.create!(name: 'DT', auth_token: SecureRandom.hex(16)) }
        let(:Authorization) { "Bearer #{internal_client.auth_token}" }

        schema ApiResponseExamples::ERROR_SCHEMA

        run_test!
      end
    end

    patch 'Change settings' do
      tags 'Configuration Settings'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Changes one or more settings at once. Every key must be configurable and every " \
                  "value must match the key's type; otherwise nothing is changed and the response " \
                  "lists the problem per key. Switches take `true`/`false`, colours a hex value " \
                  "(`#rgb`, `#rgba`, `#rrggbb`, `#rrggbbaa`), URLs an absolute http(s) URL, lists " \
                  "an array of allowed values. `null` or an empty string clears a setting that " \
                  "may be blank.#{ApiAccessRequirements::CONFIGURATION_REQUIRED}"
      parameter name: :body, in: :body, required: true, schema: {
        type: :object,
        properties: { settings: { '$ref' => '#/components/schemas/ConfigurationSettingsUpdate' } },
        required: ['settings']
      }

      response '200', 'settings changed' do
        let(:body) do
          {
            settings: {
              'brand_color' => '#AA3300',
              'process.ideas' => true,
              'map.zoom' => 12,
              'uploads.images.content_types' => ['image/png', 'image/webp']
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: { settings: { type: :object, description: 'The stored values of the changed keys' } },
                   required: ['settings']
                 }
               },
               required: ['data']

        run_test! do |response|
          settings = JSON.parse(response.body)['data']['settings']

          expect(settings).to eq(
            'brand_color' => '#aa3300',
            'process.ideas' => true,
            'map.zoom' => 12,
            'uploads.images.content_types' => ['image/png', 'image/webp']
          )
          expect(Setting.find_by(key: 'process.ideas').value).to eq('active')
          expect(Setting.find_by(key: 'uploads.images.content_types').value).to eq('image/png image/webp')

          audit = Setting.find_by(key: 'brand_color').audits.last
          expect(audit.user).to eq(api_client.content_author)
          expect(audit.comment).to eq("api_client:#{api_client.id}")
          expect(audit.audited_changes['value'].last).to eq('#aa3300')
        end
      end

      response '200', 'switch turned off is stored the way /adm stores it' do
        before { Setting.find_by(key: 'process.debates').update!(value: 'active') }

        let(:body) { { settings: { 'process.debates' => false } } }

        run_test! do
          expect(Setting.find_by(key: 'process.debates').value).to eq('')
        end
      end

      response '422', 'unknown key or wrong value type - nothing is changed' do
        before { Setting['brand_color'] = '#123456' }

        let(:body) do
          {
            settings: {
              'brand_color' => '#000000',
              'html.per_page_code_head' => '<script>alert(1)</script>',
              'map.zoom' => 'far',
              'meta_title' => "<style>\n</style>"
            }
          }
        end

        schema '$ref' => '#/components/schemas/ConfigurationValidationError'

        run_test! do |response|
          details = JSON.parse(response.body)['error']['details']

          expect(details.keys).to match_array(['html.per_page_code_head', 'map.zoom', 'meta_title'])
          expect(details['html.per_page_code_head']).to eq(['is not a configurable key'])
          expect(Setting['brand_color']).to eq('#123456')
          expect(Setting['html.per_page_code_head']).to be_blank
        end
      end

      response '422', 'colour that is not a hex value is rejected' do
        let(:body) { { settings: { 'brand_color' => 'red;}</style><script>' } } }

        schema '$ref' => '#/components/schemas/ConfigurationValidationError'

        run_test!
      end

      response '400', 'settings object missing' do
        let(:body) { { settings: 'brand_color' } }

        schema ApiResponseExamples::ERROR_SCHEMA

        run_test!
      end

      unauthorized_response
      configuration_forbidden_response

      response '403', 'forbidden - admin clients without the right cannot configure' do
        before { api_client.update_columns(instance_configuration_access: false) }

        let(:body) { { settings: { 'brand_color' => '#000000' } } }

        schema ApiResponseExamples::ERROR_SCHEMA

        run_test! do
          expect(Setting.find_by(key: 'brand_color').value).not_to eq('#000000')
        end
      end
    end
  end
end
