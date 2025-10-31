# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Deficiency Reports API', type: :request, openapi_spec: 'v1/swagger.yaml' do
  let!(:api_client) { ApiClient.create!(name: 'Test Client', registration_status: :registered) }
  let(:Authorization) { "Bearer #{api_client.auth_token}" }

  def create_minimal_prereqs
    status = DeficiencyReport::Status.create!(title: 'Open', color: 'red', icon: 'hourglass-start')
    category = DeficiencyReport::Category.create!(name: 'Road', color: 'blue', icon: 'road')
    geozone = Geozone.create!(name: "Zone #{SecureRandom.hex(2)}")
    user = User.create!(
      username: "user_#{SecureRandom.hex(4)}",
      email: "u_#{SecureRandom.hex(4)}@example.com",
      password: 'Password1!',
      geozone: geozone,
      terms_data_storage: '1',
      terms_data_protection: '1',
      terms_general: '1'
    )
    [status, category, user]
  end

  path '/api/deficiency_reports' do
    get 'List deficiency reports' do
      tags 'Deficiency Reports'
      produces 'application/json'
      security [bearer_auth: []]
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Pagination page number'
      parameter name: :per_page, in: :query, type: :integer, required: false, description: 'Items per page (default 100)'

      response '200', 'deficiency reports found' do
        before do
          status, category, = create_minimal_prereqs
          2.times do |i|
            report = DeficiencyReport.new(
              api_client_created: api_client,
              deficiency_report_category_id: category.id,
              deficiency_report_status_id: status.id,
              admin_accepted: true,
              resource_terms: true,
              map_location_attributes: { latitude: 40.0 + i, longitude: -3.0 - i, zoom: 12 },
              translations_attributes: [
                {
                  locale: 'en',
                  title: "Report #{i+1}",
                  description: "Description for report #{i+1}"
                }
              ]
            )
            report.save!(context: :api)
          end
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     deficiency_reports: { type: :array, items: { type: :object } }
                   },
                   required: ['deficiency_reports']
                 },
                 pagination: { type: :object }
               },
               required: ['data']

        run_test!
      end
    end

    post 'Create a deficiency report' do
      tags 'Deficiency Reports'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]

      parameter name: :deficiency_report, in: :body, description: 'Deficiency Report payload', schema: {
        type: :object,
        properties: {
          deficiency_report: {
            type: :object,
            properties: {
              author_id: { type: :integer, nullable: true },
              deficiency_report_category_id: { type: :integer },
              deficiency_report_status_id: { type: :integer },
              title: { type: :string },
              description: { type: :string, nullable: true },
              resource_terms: { type: :boolean },
              admin_accepted: { type: :boolean },
              map_location_attributes: {
                type: :object,
                properties: {
                  latitude: { type: :number },
                  longitude: { type: :number },
                  zoom: { type: :integer }
                },
                required: %w[latitude longitude]
              }
            },
            required: %w[deficiency_report_category_id title resource_terms map_location_attributes]
          }
        },
        required: ['deficiency_report']
      }

      response '201', 'deficiency report created' do
        let!(:pre) { create_minimal_prereqs }
        let(:status_id) { pre[0].id }
        let(:category_id) { pre[1].id }
        let(:deficiency_report) do
          {
            deficiency_report: {
              deficiency_report_category_id: category_id,
              deficiency_report_status_id: status_id,
              title: 'Broken streetlight',
              description: 'The lamp is out on 3rd street.',
              resource_terms: true,
              admin_accepted: true,
              map_location_attributes: { latitude: 40.4168, longitude: -3.7038, zoom: 12 }
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     deficiency_report: { type: :object }
                   },
                   required: ['deficiency_report']
                 }
               },
               required: ['data']

        run_test!
      end

      response '422', 'invalid request' do
        let!(:pre) { create_minimal_prereqs }
        let(:category_id) { pre[1].id }
        let(:deficiency_report) do
          {
            deficiency_report: {
              deficiency_report_category_id: category_id,
              title: '',
              resource_terms: false,
              map_location_attributes: { latitude: 40.4168, longitude: -3.7038 }
            }
          }
        end

        schema type: :object,
               properties: {
                 error: {
                   type: :object,
                   properties: {
                     messages: { type: :array, items: { type: :string } }
                   }
                 }
               }

        run_test!
      end
    end
  end

  path '/api/deficiency_reports/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'Deficiency Report ID'

    get 'Retrieve a deficiency report' do
      tags 'Deficiency Reports'
      produces 'application/json'
      security [bearer_auth: []]

      response '200', 'deficiency report found' do
        let!(:pre) { create_minimal_prereqs }
        let(:status_id) { pre[0].id }
        let(:category_id) { pre[1].id }
        let!(:record) do
          report = DeficiencyReport.new(
            api_client_created: api_client,
            deficiency_report_category_id: category_id,
            deficiency_report_status_id: status_id,
            resource_terms: true,
            admin_accepted: true,
            map_location_attributes: { latitude: 41.0, longitude: -3.0, zoom: 10 },
            translations_attributes: [
              {
                locale: 'en',
                title: 'Pothole',
                description: 'A pothole in the road'
              }
            ]
          )
          report.save!(context: :api)
          report
        end
        let(:id) { record.id }

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     deficiency_report: { type: :object }
                   },
                   required: ['deficiency_report']
                 }
               },
               required: ['data']

        run_test!
      end

      response '404', 'deficiency report not found' do
        let(:id) { 999999 }
        run_test!
      end
    end

    patch 'Update a deficiency report' do
      tags 'Deficiency Reports'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]

      parameter name: :deficiency_report, in: :body, description: 'Attributes to update on the deficiency report', schema: {
        type: :object,
        properties: {
          deficiency_report: {
            type: :object,
            properties: {
              title: { type: :string },
              deficiency_report_status_id: { type: :integer }
            }
          }
        }
      }

      response '200', 'deficiency report updated' do
        let!(:pre) { create_minimal_prereqs }
        let(:status_id) { pre[0].id }
        let(:category_id) { pre[1].id }
        let!(:record) do
          report = DeficiencyReport.new(
            api_client_created: api_client,
            deficiency_report_category_id: category_id,
            deficiency_report_status_id: status_id,
            resource_terms: true,
            admin_accepted: true,
            map_location_attributes: { latitude: 41.0, longitude: -3.0, zoom: 10 },
            translations_attributes: [
              {
                locale: 'en',
                title: 'Graffiti',
                description: 'Graffiti on the wall'
              }
            ]
          )
          report.save!(context: :api)
          report
        end
        let(:id) { record.id }
        let(:deficiency_report) do
          {
            deficiency_report: {
              title: 'Graffiti updated'
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     deficiency_report: { type: :object }
                   },
                   required: ['deficiency_report']
                 }
               },
               required: ['data']

        run_test!
      end

      response '422', 'invalid request' do
        let!(:pre) { create_minimal_prereqs }
        let(:status_id) { pre[0].id }
        let(:category_id) { pre[1].id }
        let!(:record) do
          report = DeficiencyReport.new(
            api_client_created: api_client,
            deficiency_report_category_id: category_id,
            deficiency_report_status_id: status_id,
            resource_terms: true,
            admin_accepted: true,
            map_location_attributes: { latitude: 41.0, longitude: -3.0, zoom: 10 },
            translations_attributes: [
              {
                locale: 'en',
                title: 'Trash overflow',
                description: 'Trash bin is overflowing'
              }
            ]
          )
          report.save!(context: :api)
          report
        end
        let(:id) { record.id }
        let(:deficiency_report) do
          {
            deficiency_report: {
              title: ''
            }
          }
        end

        schema type: :object,
               properties: {
                 error: {
                   type: :object,
                   properties: {
                     messages: { type: :array, items: { type: :string } }
                   }
                 }
               }

        run_test!
      end
    end
  end
end


