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
                     deficiency_reports: { type: :array, items: { type: :object } }
                   },
                   required: ['deficiency_reports']
                 },
                 pagination: { type: :object }
               },
               required: ['data']

        run_test!
      end

      unauthorized_response
    end

    post 'Create a deficiency report' do
      tags 'Deficiency Reports'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Submit a new deficiency report for a maintenance issue or infrastructure problem. Reports must include a location (latitude/longitude) and category. Supports geographic mapping, image attachments for documenting the issue, and admin review before publishing. Requires acceptance of terms. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      parameter name: :deficiency_report, in: :body, description: 'Deficiency report with required title, description, location, category, and terms acceptance. Optional image attachment for documenting the issue.', schema: {
        type: :object,
        properties: {
          deficiency_report: {
            type: :object,
            properties: {
              deficiency_report_category_id: { type: :integer },
              deficiency_report_status_id: { type: :integer, nullable: true },
              title: { type: :string },
              description: { type: :string, nullable: true },
              summary: { type: :string, nullable: true, description: 'Brief summary or overview of the deficiency report' },
              official_answer: { type: :string, nullable: true, description: 'Official response or answer from administrators regarding the reported issue' },
              reporter_answer: { type: :string, nullable: true, description: 'Answer e-mailed to the reporter and not shown publicly; used when the setting "separate reporter answer" is enabled, in which case official_answer is the public answer only' },
              on_behalf_of: { type: :string, nullable: true, description: 'Name of the organization or group submitting on behalf of' },
              deficiency_report_intake_channel_id: { type: :integer, nullable: true, description: 'ID of the intake channel the report reached the municipality through, as listed by GET /api/deficiency_report_intake_channels. Required for a report filed on_behalf_of a citizen when the setting "intake channel required for on-behalf-of reports" is on; otherwise the default channel is used. An id that does not exist is rejected with 422.' },
              documents_attributes: {
                type: :array,
                nullable: true,
                description: 'Document attachments (PDFs etc.). Upload each file as base64, bare or as a data URI (data:application/pdf;base64,...). Add new documents, or remove one by sending its id with _destroy=true. New documents are attributed to the content author of the API client. Returned documents carry a download url.',
                items: {
                  type: :object,
                  properties: {
                    id: { type: :integer, nullable: true, description: 'ID of an existing document; omit for new documents' },
                    title: { type: :string, nullable: true, description: 'Document title; also used for the file name' },
                    attachment: { type: :string, nullable: true, description: 'Base64-encoded file. Invalid base64 returns 422.' },
                    cached_attachment: { type: :string, nullable: true },
                    _destroy: { type: :boolean, nullable: true, description: 'Set to true to remove this document' }
                  }
                }
              },
              video_url: { type: :string, nullable: true, description: 'URL to a video documenting the deficiency (YouTube, Vimeo, etc.)' },
              responsible_id: { type: :integer, nullable: true, description: 'ID of the officer or officer group assigned to address this deficiency' },
              responsible_type: { type: :string, nullable: true, enum: ['DeficiencyReport::Officer', 'DeficiencyReport::OfficerGroup'], description: 'Type of the responsible party. Only officers and officer groups can be made responsible; any other type, or an id that does not exist, is rejected with 422.' },
              tag_list: { type: :string, nullable: true, description: 'Comma-separated list of tags for categorization' },
              resource_terms: { type: :boolean },
              admin_accepted: { type: :boolean, nullable: true },
              map_location_attributes: {
                type: :object,
                nullable: true,
                description: 'Geographic location data for mapping the deficiency report',
                properties: {
                  id: { type: :integer, nullable: true },
                  latitude: { type: :number, description: 'Latitude coordinate' },
                  longitude: { type: :number, description: 'Longitude coordinate' },
                  altitude: { type: :number, nullable: true },
                  zoom: { type: :integer, nullable: true },
                  features: { type: :string, nullable: true },
                  rendering_library: { type: :string, nullable: true },
                  show_admin_shape: { type: :boolean, nullable: true },
                  _destroy: { type: :boolean, nullable: true }
                },
                required: %w[latitude longitude]
              },
              image_attributes: {
                type: :object,
                nullable: true,
                description: 'Optional: Image documenting the deficiency issue (photo of damage, problem area, etc.). Upload as base64-encoded data. Highly recommended for visual evidence of the reported problem.',
                properties: {
                  id: { type: :integer, nullable: true },
                  title: { type: :string, nullable: true, description: 'Image caption, alt text, or brief description. Used for accessibility and displayed with the image. Helps visually-impaired users understand the image content.' },
                  attachment: { type: :string, nullable: true, description: 'Base64-encoded image file. Required when adding a new image. Supported formats: JPEG, PNG, GIF, WebP (recommended max 5MB for optimal performance).' },
                  cached_attachment: { type: :string, nullable: true },
                  credits: { type: :string, nullable: true, description: 'Image source attribution, photographer/artist name, or copyright information. Displayed with the image to give proper credit.' },
                  ai_generated: { type: :boolean, nullable: true, description: 'Set to true when the image was created or edited with AI; the public page then shows the AI disclosure label' },
                  user_id: { type: :integer, nullable: true },
                  _destroy: { type: :boolean, nullable: true, description: 'Set to true to remove the current image from the deficiency report. Does not affect other report properties.' }
                }
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
              resource_terms: true,
              admin_accepted: true,
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
                     deficiency_report: { type: :object }
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
              resource_terms: true,
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
              resource_terms: true,
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
              resource_terms: true,
              admin_accepted: true,
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
                     deficiency_report: { type: :object }
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

      unauthorized_response { let(:id) { 1 } }
    end

    patch 'Update a deficiency report' do
      tags 'Deficiency Reports'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Update an existing deficiency report with new information, status, or image. Can add, replace, or remove the report image. All fields are optional - only provide fields to change. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      parameter name: :deficiency_report, in: :body, description: 'Deficiency report attributes to update (title, description, status, image). Any field not provided remains unchanged.', schema: {
        type: :object,
        properties: {
          deficiency_report: {
            type: :object,
            properties: {
              title: { type: :string, nullable: true },
              description: { type: :string, nullable: true },
              summary: { type: :string, nullable: true, description: 'Brief summary or overview of the deficiency report' },
              official_answer: { type: :string, nullable: true, description: 'Official response or answer from administrators regarding the reported issue' },
              reporter_answer: { type: :string, nullable: true, description: 'Answer e-mailed to the reporter and not shown publicly; used when the setting "separate reporter answer" is enabled, in which case official_answer is the public answer only' },
              deficiency_report_category_id: { type: :integer, nullable: true },
              deficiency_report_status_id: { type: :integer, nullable: true },
              on_behalf_of: { type: :string, nullable: true, description: 'Name of the organization or group submitting on behalf of' },
              deficiency_report_intake_channel_id: { type: :integer, nullable: true, description: 'ID of the intake channel the report reached the municipality through, as listed by GET /api/deficiency_report_intake_channels. Required for a report filed on_behalf_of a citizen when the setting "intake channel required for on-behalf-of reports" is on; otherwise the default channel is used. An id that does not exist is rejected with 422.' },
              documents_attributes: {
                type: :array,
                nullable: true,
                description: 'Document attachments (PDFs etc.). Upload each file as base64, bare or as a data URI (data:application/pdf;base64,...). Add new documents, or remove one by sending its id with _destroy=true. New documents are attributed to the content author of the API client. Returned documents carry a download url.',
                items: {
                  type: :object,
                  properties: {
                    id: { type: :integer, nullable: true, description: 'ID of an existing document; omit for new documents' },
                    title: { type: :string, nullable: true, description: 'Document title; also used for the file name' },
                    attachment: { type: :string, nullable: true, description: 'Base64-encoded file. Invalid base64 returns 422.' },
                    cached_attachment: { type: :string, nullable: true },
                    _destroy: { type: :boolean, nullable: true, description: 'Set to true to remove this document' }
                  }
                }
              },
              video_url: { type: :string, nullable: true, description: 'URL to a video documenting the deficiency (YouTube, Vimeo, etc.)' },
              responsible_id: { type: :integer, nullable: true, description: 'ID of the officer or officer group assigned to address this deficiency' },
              responsible_type: { type: :string, nullable: true, enum: ['DeficiencyReport::Officer', 'DeficiencyReport::OfficerGroup'], description: 'Type of the responsible party. Only officers and officer groups can be made responsible; any other type, or an id that does not exist, is rejected with 422.' },
              tag_list: { type: :string, nullable: true, description: 'Comma-separated list of tags for categorization' },
              map_location_attributes: {
                type: :object,
                nullable: true,
                description: 'Geographic location data for mapping the deficiency report',
                properties: {
                  id: { type: :integer, nullable: true },
                  latitude: { type: :number, nullable: true, description: 'Latitude coordinate' },
                  longitude: { type: :number, nullable: true, description: 'Longitude coordinate' },
                  altitude: { type: :number, nullable: true },
                  zoom: { type: :integer, nullable: true },
                  features: { type: :string, nullable: true },
                  rendering_library: { type: :string, nullable: true },
                  show_admin_shape: { type: :boolean, nullable: true },
                  _destroy: { type: :boolean, nullable: true }
                }
              },
              image_attributes: {
                type: :object,
                nullable: true,
                description: 'Update, replace, or remove the deficiency report image. Attach a new image (base64-encoded), update metadata (title/credits), or set _destroy=true to remove. All fields are optional.',
                properties: {
                  id: { type: :integer, nullable: true },
                  title: { type: :string, nullable: true, description: 'Updated image caption or alt text. Improves accessibility by describing the image content for screen readers.' },
                  attachment: { type: :string, nullable: true, description: 'Base64-encoded image file to replace current image. Supported formats: JPEG, PNG, GIF, WebP (recommended max 5MB). Omit to keep existing image.' },
                  cached_attachment: { type: :string, nullable: true },
                  credits: { type: :string, nullable: true, description: 'Updated image source attribution, photographer/artist name, or copyright notice. Properly credits original creators.' },
                  ai_generated: { type: :boolean, nullable: true, description: 'Set to true when the image was created or edited with AI; the public page then shows the AI disclosure label' },
                  user_id: { type: :integer, nullable: true },
                  _destroy: { type: :boolean, nullable: true, description: 'Set to true to remove the image entirely from the deficiency report while preserving the report text and other properties.' }
                }
              }
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
                     deficiency_report: { type: :object }
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
