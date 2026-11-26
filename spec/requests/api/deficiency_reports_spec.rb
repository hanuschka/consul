require 'swagger_helper'

RSpec.describe 'Deficiency Reports API', type: :request, openapi_spec: 'v1/swagger.yaml' do
  let!(:api_client) { create_api_client }
  let(:Authorization) { "Bearer #{api_client.access_token}" }

  let(:existing_deficiency_report) do
    status, category, user = create_minimal_prereqs

    create_deficiency_report(user, category, status)
  end

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

  def create_deficiency_report(author, category, status, title: 'Existing Deficiency Report')
    report = DeficiencyReport.new(
      author: author,
      deficiency_report_category_id: category.id,
      deficiency_report_status_id: status.id,
      admin_accepted: true,
      resource_terms: true,
      title: title,
      map_location_attributes: { latitude: 40.0, longitude: -3.0, zoom: 12 }
    )
    report.save!
    report
  end

  path '/api/deficiency_reports' do
    get 'List deficiency reports' do
      tags 'Deficiency Reports'
      produces 'application/json'
      security [bearer_auth: []]
      description "Retrieve a paginated list of deficiency reports (citizen-reported maintenance/repair issues). Reports include location data, category, status, and the author's public name (null when the author hid their activity). Admin clients additionally get author_id, on_behalf_of, the responsible officer or group and reporter_answer, and can filter by author_id. Useful for public issue tracking and municipal maintenance prioritization. #{ApiAccessRequirements::GET_READ_ONLY}"
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Pagination page number (**default:** 1)'
      parameter name: :per_page, in: :query, type: :integer, required: false, description: 'Number of items per page (**default:** 500, max: 2000)'
      parameter name: :category_id, in: :query, type: :integer, required: false, description: 'Only reports of this category'
      parameter name: :subcategory_id, in: :query, type: :integer, required: false, description: 'Only reports of this subcategory'
      parameter name: :status_id, in: :query, type: :integer, required: false, description: 'Only reports in this status'
      parameter name: :author_id, in: :query, type: :integer, required: false, description: 'Only reports of this author. Admin clients only; read-only clients sending it get 403.'
      parameter name: :assigned, in: :query, type: :string, enum: %w[true false], required: false, description: 'true: only reports with a responsible officer or group, false: only unassigned ones. Admin clients only; read-only clients sending it get 403.'
      parameter name: :archived, in: :query, type: :string, enum: %w[true false], required: false, description: 'true: only archived reports, false: only reports that are not archived'
      parameter name: :closed, in: :query, type: :string, enum: %w[true false], required: false, description: 'true: only reports in a status that closes reports, false: only open ones'
      parameter name: :search, in: :query, type: :string, required: false, description: 'Full-text search in title, description and tags'
      parameter name: :order, in: :query, type: :string, enum: %w[hot_score most_commented newest], required: false, description: 'Sort order: hot_score (most active first), most_commented, or newest (**default**)'

      response '200', 'deficiency reports found and returned' do
        before do
          status, category, = create_minimal_prereqs
          2.times do |i|
            report = DeficiencyReport.new(
              author: api_client.user,
              deficiency_report_category_id: category.id,
              deficiency_report_status_id: status.id,
              admin_accepted: true,
              resource_terms: true,
              title: "Deficiency Report #{i}",
              map_location_attributes: { latitude: 40.0 + i, longitude: -3.0 - i, zoom: 12 }
            )
            report.save!
          end
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     deficiency_reports: { type: :array, items: { '$ref' => '#/components/schemas/DeficiencyReport' } }
                   },
                   required: ['deficiency_reports']
                 },
                 pagination: { type: :object }
               },
               required: ['data']

        run_test!
      end

      response '403', 'read-only client sent an admin-only filter' do
        let(:assigned) { 'false' }

        before { api_client.update!(access_level: :public_data) }

        schema ApiResponseExamples::ERROR_SCHEMA

        run_test! do |response|
          expect(JSON.parse(response.body)['error']['type']).to eq('forbidden')
        end
      end

      unauthorized_response
    end

    post 'Create a deficiency report' do
      tags 'Deficiency Reports'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Submit a new deficiency report for a maintenance issue or infrastructure problem. Reports must include a location (latitude/longitude) and category. Supports geographic mapping, image attachments for documenting the issue, and admin review before publishing. Requires acceptance of terms. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      parameter name: :deficiency_report, in: :body, description: 'Deficiency report with a category, a title and, when the instance requires it, a location. Image, documents and official answer files arrive base64 encoded.', schema: { '$ref' => '#/components/schemas/DeficiencyReportWriteParams' }

      response '201', 'deficiency report created' do
        let!(:pre) { create_minimal_prereqs }
        let(:status_id) { pre[0].id }
        let(:category_id) { pre[1].id }
        let(:deficiency_report) do
          {
            deficiency_report: {
              deficiency_report_category_id: category_id,
              deficiency_report_status_id: status_id,
              title: 'Test Deficiency Report',
              map_location_attributes: { latitude: 40.4168, longitude: -3.7038, zoom: 12 }
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     deficiency_report: { '$ref' => '#/components/schemas/DeficiencyReport' }
                   },
                   required: ['deficiency_report']
                 }
               },
               required: ['data']

        run_test!
      end

      response '201', 'deficiency report filed on behalf of a citizen with intake channel and document' do
        let!(:pre) { create_minimal_prereqs }
        let(:intake_channel) { create(:deficiency_report_intake_channel) }
        let(:deficiency_report) do
          {
            deficiency_report: {
              deficiency_report_category_id: pre[1].id,
              deficiency_report_status_id: pre[0].id,
              deficiency_report_intake_channel_id: intake_channel.id,
              on_behalf_of: 'Citizen at the counter',
              title: 'Reported at the counter',
              map_location_attributes: { latitude: 40.4168, longitude: -3.7038, zoom: 12 },
              documents_attributes: [
                {
                  title: 'Counter protocol',
                  attachment: "data:application/pdf;base64,#{Base64.strict_encode64("%PDF-1.4\n%%EOF\n")}"
                }
              ]
            }
          }
        end

        before { Setting["deficiency_reports.intake_channel_required_for_on_behalf_of"] = "active" }

        run_test! do |response|
          report_data = JSON.parse(response.body)['data']['deficiency_report']
          report = DeficiencyReport.find(report_data['id'])

          expect(report.intake_channel).to eq(intake_channel)
          expect(report_data['documents'].first).to include(
            'title' => 'Counter protocol',
            'attachment_file_name' => 'counter-protocol.pdf'
          )
          expect(report_data['documents'].first['url']).to be_present
        end
      end

      response '422', 'unknown intake channel' do
        let!(:pre) { create_minimal_prereqs }
        let(:deficiency_report) do
          {
            deficiency_report: {
              deficiency_report_category_id: pre[1].id,
              deficiency_report_intake_channel_id: 999999,
              title: 'Report with unknown channel',
              map_location_attributes: { latitude: 40.4168, longitude: -3.7038, zoom: 12 }
            }
          }
        end

        schema ApiResponseExamples::ERROR_SCHEMA

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

      response '201', 'deficiency report created with base64 image' do
        let!(:pre) { create_minimal_prereqs }
        let(:status_id) { pre[0].id }
        let(:category_id) { pre[1].id }
        let(:deficiency_report) do
          {
            deficiency_report: {
              deficiency_report_category_id: category_id,
              deficiency_report_status_id: status_id,
              title: 'Test Deficiency Report with Image',
              map_location_attributes: { latitude: 40.4168, longitude: -3.7038, zoom: 12 },
              image_attributes: {
                attachment: base64_fixture('clippy.jpg'),
                title: 'Deficiency Photo'
              }
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     deficiency_report: { '$ref' => '#/components/schemas/DeficiencyReport' }
                   },
                   required: ['deficiency_report']
                 }
               },
               required: ['data']

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']['deficiency_report']).to be_present
          expect(response.status).to eq(201)
        end
      end

      unauthorized_response
      forbidden_response
    end
  end

  path '/api/deficiency_reports/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'Deficiency Report ID'

    get 'Retrieve a deficiency report' do
      tags 'Deficiency Reports'
      produces 'application/json'
      security [bearer_auth: []]
      description "Retrieve a single deficiency report by ID with all its details. Read-only clients get 404 for a report an admin has not accepted yet; admin clients get it, plus the admin-only fields listed on the index. #{ApiAccessRequirements::GET_READ_ONLY}"

      response '200', 'deficiency report found' do
        let!(:pre) { create_minimal_prereqs }
        let(:status_id) { pre[0].id }
        let(:category_id) { pre[1].id }
        let!(:record) do
          report = DeficiencyReport.new(
            author: api_client.user,
            deficiency_report_category_id: category_id,
            deficiency_report_status_id: status_id,
            resource_terms: true,
            admin_accepted: true,
            title: 'Test Deficiency Report',
            map_location_attributes: { latitude: 41.0, longitude: -3.0, zoom: 10 }
          )
          report.save!
          report
        end
        let(:id) { record.id }

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     deficiency_report: { '$ref' => '#/components/schemas/DeficiencyReport' }
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

      unauthorized_response { let(:id) { 1 } }
    end

    patch 'Update a deficiency report' do
      tags 'Deficiency Reports'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Update an existing deficiency report with new information, status, or image. Can add, replace, or remove the report image. All fields are optional - only provide fields to change. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      parameter name: :deficiency_report, in: :body, description: 'Deficiency report attributes to update. Any field not provided remains unchanged.', schema: { '$ref' => '#/components/schemas/DeficiencyReportWriteParams' }

      response '200', 'deficiency report updated' do
        let!(:pre) { create_minimal_prereqs }
        let(:status_id) { pre[0].id }
        let(:category_id) { pre[1].id }
        let!(:record) do
          report = DeficiencyReport.new(
            author: api_client.user,
            deficiency_report_category_id: category_id,
            deficiency_report_status_id: status_id,
            resource_terms: true,
            admin_accepted: true,
            title: 'Original Title',
            map_location_attributes: { latitude: 41.0, longitude: -3.0, zoom: 10 }
          )
          report.save!
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
                     deficiency_report: { '$ref' => '#/components/schemas/DeficiencyReport' }
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
            author: api_client.user,
            deficiency_report_category_id: category_id,
            deficiency_report_status_id: status_id,
            resource_terms: true,
            admin_accepted: true,
            title: 'Original Title',
            map_location_attributes: { latitude: 41.0, longitude: -3.0, zoom: 10 }
          )
          report.save!
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

        before do
          allow_any_instance_of(DeficiencyReport).to receive(:save).and_return(false)
          errors_mock = double('errors').as_null_object
          allow(errors_mock).to receive(:full_messages).and_return(['Title can\'t be blank'])
          allow_any_instance_of(DeficiencyReport).to receive(:errors).and_return(errors_mock)
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

      response '200', 'texts per language, subcategory, official answer files and a drawn area' do
        let(:record) { existing_deficiency_report }
        let(:id) { record.id }
        let(:subcategory) { DeficiencyReport::Subcategory.create!(category: record.category, name: 'Schlagloch') }
        let(:polygon) { [[[-3.0, 40.0], [-2.9, 40.0], [-2.9, 40.1], [-3.0, 40.0]]] }
        let(:deficiency_report) do
          {
            deficiency_report: {
              deficiency_report_subcategory_id: subcategory.id,
              translations: {
                de: { title: 'Schlagloch Hauptstraße', official_answer: 'Wird repariert' },
                en: { title: 'Pothole on Main Street', official_answer: 'Repair scheduled' }
              },
              official_answer_documents: [
                { title: 'Antwort', attachment: "data:application/pdf;base64,#{Base64.strict_encode64(File.binread(Rails.root.join('spec/fixtures/files/empty.pdf')))}" }
              ],
              map_location_attributes: {
                features: {
                  type: 'FeatureCollection',
                  features: [{ type: 'Feature', geometry: { type: 'Polygon', coordinates: polygon }, properties: {} }]
                }
              }
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     deficiency_report: { '$ref' => '#/components/schemas/DeficiencyReport' }
                   },
                   required: ['deficiency_report']
                 }
               },
               required: ['data']

        run_test! do |response|
          report_data = JSON.parse(response.body)['data']['deficiency_report']

          expect(report_data['subcategory']).to eq('id' => subcategory.id, 'name' => 'Schlagloch')
          expect(report_data['translations']['de']['official_answer']).to eq('Wird repariert')
          expect(report_data['translations']['en']['title']).to eq('Pothole on Main Street')
          expect(report_data['official_answer_documents'].first).to include('filename' => 'antwort.pdf')
          expect(report_data['map_location']['features']['features'].first['geometry']['coordinates']).to eq(polygon)
          expect(MapLocation.where(mappable: record).count).to eq(1)
        end
      end

      response '200', 'official answer file removed' do
        let(:record) do
          existing_deficiency_report.tap do |report|
            report.official_answer_documents.attach(
              io: File.open(Rails.root.join('spec/fixtures/files/empty.pdf')),
              filename: 'alt.pdf',
              content_type: 'application/pdf'
            )
          end
        end
        let(:id) { record.id }
        let(:deficiency_report) do
          { deficiency_report: { remove_official_answer_document_ids: [record.official_answer_documents.first.id] } }
        end

        run_test! do |response|
          expect(JSON.parse(response.body)['data']['deficiency_report']['official_answer_documents']).to eq([])
        end
      end

      response '200', 'deficiency report updated with base64 image' do
        let!(:pre) { create_minimal_prereqs }
        let(:status_id) { pre[0].id }
        let(:category_id) { pre[1].id }
        let!(:record) do
          report = DeficiencyReport.new(
            author: api_client.user,
            deficiency_report_category_id: category_id,
            deficiency_report_status_id: status_id,
            resource_terms: true,
            admin_accepted: true,
            title: 'Original Title',
            map_location_attributes: { latitude: 41.0, longitude: -3.0, zoom: 10 }
          )
          report.save!
          report
        end
        let(:id) { record.id }
        let(:deficiency_report) do
          {
            deficiency_report: {
              title: 'Graffiti updated',
              image_attributes: {
                attachment: base64_fixture('clippy.jpg'),
                title: 'Updated Deficiency Photo'
              }
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     deficiency_report: { '$ref' => '#/components/schemas/DeficiencyReport' }
                   },
                   required: ['deficiency_report']
                 }
               },
               required: ['data']

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']['deficiency_report']).to be_present
          expect(response.status).to eq(200)
        end
      end

      unauthorized_response { let(:id) { 1 } }
      forbidden_response { let(:id) { existing_deficiency_report.id } }
    end
  end

end
