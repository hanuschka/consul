# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Milestones API', type: :request, openapi_spec: 'v1/swagger.yaml' do
  let!(:api_client) { create_api_client }
  let(:Authorization) { "Bearer #{api_client.access_token}" }

  let(:existing_milestone_phase) { create_projekt_phase('ProjektPhase::MilestonePhase') }

  milestone_response_schema = {
    type: :object,
    properties: {
      data: {
        type: :object,
        properties: { milestone: { '$ref' => '#/components/schemas/Milestone' } },
        required: ['milestone']
      }
    },
    required: ['data']
  }

  def create_milestone(milestone_phase, attributes = {})
    milestone_phase.milestones.create!(
      {
        title: 'Phase 1 Complete',
        description: 'First phase completed successfully',
        publication_date: Date.current
      }.merge(attributes)
    )
  end

  path '/api/projekt_phases/{projekt_phase_id}/milestones' do
    parameter name: :projekt_phase_id, in: :path, type: :integer, description: 'Projekt Phase ID (MilestonePhase)'

    get 'List all milestones' do
      tags 'Milestones'
      produces 'application/json'
      security [bearer_auth: []]
      description "Retrieve all milestones for a projekt phase, with their texts in every language, status, image and documents. Read-only clients get 403 for a phase the public site doesn't show.#{ApiAccessRequirements::GET_READ_ONLY}"
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Pagination page number (**default:** 1)'
      parameter name: :per_page, in: :query, type: :integer, required: false, description: 'Number of items per page (**default:** 500, max: 2000)'

      response '200', 'milestones found and returned' do
        let(:milestone_phase) { existing_milestone_phase }
        let(:projekt_phase_id) { milestone_phase.id }
        let!(:milestone) { create_milestone(milestone_phase) }

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     milestones: {
                       type: :array,
                       items: { '$ref' => '#/components/schemas/Milestone' }
                     }
                   },
                   required: ['milestones']
                 },
                 pagination: Schemas::Miscellaneous::PAGINATION_RESPONSE_SCHEMA
               },
               required: ['data', 'pagination']

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']['milestones'].length).to eq(1)
          expect(data['data']['milestones'][0]['title']).to eq('Phase 1 Complete')
          expect(data['data']['milestones'][0]['translations'].keys).to include(I18n.locale.to_s)
        end
      end

      response '403', 'phase hidden from read-only clients' do
        let(:projekt_phase_id) { existing_milestone_phase.id }

        before do
          api_client.update!(access_level: :public_data)
          existing_milestone_phase.update_column(:frontend_visibility, false)
        end

        run_test!
      end

      response '404', 'projekt phase not found' do
        let(:projekt_phase_id) { 999999 }

        run_test!
      end

      unauthorized_response { let(:projekt_phase_id) { 1 } }
    end

    post 'Create a milestone' do
      tags 'Milestones'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Create a new milestone for a MilestonePhase. Milestones require a publication_date and either a description or a status_id. Texts can be sent per language in translations; image and documents arrive base64 encoded.#{ApiAccessRequirements::ADMIN_REQUIRED}"

      parameter name: :milestone, in: :body, description: 'Milestone attributes', schema: { '$ref' => '#/components/schemas/MilestoneWriteParams' }

      response '201', 'milestone created successfully' do
        let(:projekt_phase_id) { existing_milestone_phase.id }
        let(:milestone) do
          {
            milestone: {
              publication_date: '2026-05-01',
              translations: {
                de: { title: 'Baubeginn', description: 'Der Bau beginnt' },
                en: { title: 'Construction Started', description: 'Ground breaking ceremony' }
              },
              documents_attributes: [
                { title: 'Bauplan', attachment: Base64.strict_encode64(File.binread(Rails.root.join('spec/fixtures/files/empty.pdf'))) }
              ]
            }
          }
        end

        schema milestone_response_schema

        run_test! do |response|
          milestone_data = JSON.parse(response.body)['data']['milestone']

          expect(milestone_data['translations']['de']['title']).to eq('Baubeginn')
          expect(milestone_data['translations']['en']['title']).to eq('Construction Started')
          expect(milestone_data['publication_date']).to include('2026-05-01')
          expect(milestone_data['documents'].first['title']).to eq('Bauplan')
        end
      end

      response '201', 'milestone created with status_id instead of description' do
        let(:projekt_phase_id) { existing_milestone_phase.id }
        let!(:status) { Milestone::Status.create!(name: 'In Progress', description: 'Work has started') }
        let(:milestone) do
          {
            milestone: {
              title: 'Phase 2',
              publication_date: '2026-06-15',
              status_id: status.id
            }
          }
        end

        schema milestone_response_schema

        run_test! do |response|
          milestone_data = JSON.parse(response.body)['data']['milestone']

          expect(milestone_data['status_id']).to eq(status.id)
          expect(milestone_data['status']['description']).to eq('Work has started')
        end
      end

      response '422', 'missing required fields' do
        let(:projekt_phase_id) { existing_milestone_phase.id }
        let(:milestone) do
          {
            milestone: {
              title: 'No date or description'
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

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['messages']).to be_present
        end
      end

      response '404', 'projekt phase not found' do
        let(:projekt_phase_id) { 999999 }
        let(:milestone) do
          {
            milestone: {
              title: 'Test',
              description: 'Test',
              publication_date: '2026-01-01'
            }
          }
        end

        run_test!
      end

      unauthorized_response { let(:projekt_phase_id) { 1 } }

      forbidden_response { let(:projekt_phase_id) { existing_milestone_phase.id } }
    end
  end

  path '/api/milestones/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'Milestone ID'

    get 'Retrieve a milestone' do
      tags 'Milestones'
      produces 'application/json'
      security [bearer_auth: []]
      description "Retrieve one milestone of any record that has milestones (phases, proposals, budget investments, deficiency reports). Read-only clients get 403 when the public site doesn't show the record the milestone belongs to.#{ApiAccessRequirements::GET_READ_ONLY}"

      response '200', 'milestone found' do
        let(:id) { create_milestone(existing_milestone_phase).id }

        schema milestone_response_schema

        run_test!
      end

      response '403', 'milestone of a hidden phase, read-only client' do
        let(:id) { create_milestone(existing_milestone_phase).id }

        before do
          api_client.update!(access_level: :public_data)
          existing_milestone_phase.update_column(:active, false)
        end

        run_test!
      end

      response '404', 'milestone not found' do
        let(:id) { 999999 }

        run_test!
      end

      unauthorized_response { let(:id) { 1 } }
    end

    patch 'Update a milestone' do
      tags 'Milestones'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Update a milestone. Only the fields sent change; the record it belongs to can't be changed. Documents listed with an id and _destroy: true are removed.#{ApiAccessRequirements::ADMIN_REQUIRED}"

      parameter name: :milestone, in: :body, schema: { '$ref' => '#/components/schemas/MilestoneWriteParams' }

      response '200', 'milestone updated' do
        let(:existing_milestone) { create_milestone(existing_milestone_phase) }
        let(:id) { existing_milestone.id }
        let(:other_locale) { (I18n.available_locales.map(&:to_s) - [I18n.locale.to_s]).first }
        let(:milestone) do
          {
            milestone: {
              translations: { other_locale => { title: 'Phase 1 done', description: 'Done', custom_date: 'Spring 2026' } },
              milestoneable_id: 0
            }
          }
        end

        schema milestone_response_schema

        run_test! do |response|
          milestone_data = JSON.parse(response.body)['data']['milestone']

          expect(milestone_data['translations'][other_locale]['title']).to eq('Phase 1 done')
          expect(milestone_data['translations'][other_locale]['custom_date']).to eq('Spring 2026')
          expect(milestone_data['translations'][I18n.locale.to_s]['title']).to eq('Phase 1 Complete')
          expect(existing_milestone.reload.milestoneable).to eq(existing_milestone_phase)
        end
      end

      response '422', 'invalid values' do
        let(:id) { create_milestone(existing_milestone_phase).id }
        let(:milestone) { { milestone: { publication_date: '' } } }

        run_test!
      end

      forbidden_response { let(:id) { create_milestone(existing_milestone_phase).id } }
    end

    delete 'Delete a milestone' do
      tags 'Milestones'
      produces 'application/json'
      security [bearer_auth: []]
      description "Delete a milestone together with its image and documents.#{ApiAccessRequirements::ADMIN_REQUIRED}"

      response '200', 'milestone deleted' do
        let(:id) { create_milestone(existing_milestone_phase).id }

        run_test! do
          expect(Milestone.exists?(id)).to be(false)
        end
      end

      response '404', 'milestone not found' do
        let(:id) { 999999 }

        run_test!
      end

      forbidden_response { let(:id) { create_milestone(existing_milestone_phase).id } }
    end
  end
end
