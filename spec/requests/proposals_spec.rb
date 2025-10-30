# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Proposals API', type: :request, openapi_spec: 'v1/swagger.yaml' do
  let!(:api_client) { ApiClient.create!(name: 'Test Client', registration_status: :registered) }
  let(:Authorization) { "Bearer #{api_client.auth_token}" }

  def create_phase_with_context
    projekt = Projekt.create!(name: 'Projekt For Proposals')
    geozone = Geozone.create!(name: "Zone #{SecureRandom.hex(2)}")
    phase = projekt.projekt_phases.create!(type: 'ProjektPhase::ProposalPhase', active: true, phase_tab_name: 'Proposals')
    [projekt, geozone, phase]
  end

  path '/api/projekt_phases/{projekt_phase_id}/proposals' do
    parameter name: :projekt_phase_id, in: :path, type: :integer, description: 'Projekt Phase ID'

    get 'List proposals for a projekt phase' do
      tags 'Proposals'
      produces 'application/json'
      security [bearer_auth: []]
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Pagination page number'
      parameter name: :per_page, in: :query, type: :integer, required: false, description: 'Items per page (default 100)'
      parameter name: :for_public_render, in: :query, type: :boolean, required: false, description: 'If true, filters to proposals visible for public render'

      response '200', 'proposals found' do
        before do
          _projekt, geozone, phase = create_phase_with_context
          2.times do |i|
            Proposal.create!(
              projekt_phase: phase,
              geozone: geozone,
              responsible_name: 'John Doe',
              admin_accepted: true,
              resource_terms: true,
              title: "Proposal #{i + 1}",
              description: "Description #{i + 1}"
            )
          end
        end

        let(:projekt_phase_id) { ProjektPhase.last.id }

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     proposals: { type: :array, items: { type: :object } }
                   },
                   required: ['proposals']
                 },
                 pagination: { type: :object }
               },
               required: ['data']

        run_test!
      end
    end

    post 'Create a proposal' do
      tags 'Proposals'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]

      parameter name: :proposal, in: :body, description: 'Proposal creation payload', schema: {
        type: :object,
        properties: {
          proposal: {
            type: :object,
            properties: {
              title: { type: :string },
              description: { type: :string },
              responsible_name: { type: :string },
              geozone_id: { type: :integer },
              resource_terms: { type: :boolean }
            },
            required: %w[title description responsible_name geozone_id resource_terms]
          }
        },
        required: ['proposal']
      }

      response '201', 'proposal created' do
        let!(:context) { create_phase_with_context }
        let(:projekt_phase_id) { context[2].id }
        let(:geozone_id) { context[1].id }
        let(:proposal) do
          {
            proposal: {
              title: 'New Proposal',
              description: 'A meaningful description',
              responsible_name: 'Jane Smith',
              geozone_id: geozone_id,
              resource_terms: true
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     proposal: { type: :object }
                   },
                   required: ['proposal']
                 }
               },
               required: ['data']

        run_test!
      end

      response '422', 'invalid request' do
        let!(:context) { create_phase_with_context }
        let(:projekt_phase_id) { context[2].id }
        let(:proposal) do
          {
            proposal: {
              title: '',
              description: '',
              responsible_name: '',
              geozone_id: nil,
              resource_terms: false
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

  path '/api/proposals/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'Proposal ID'

    get 'Retrieve a proposal' do
      tags 'Proposals'
      produces 'application/json'
      security [bearer_auth: []]

      response '200', 'proposal found' do
        let!(:context) { create_phase_with_context }
        let!(:record) do
          Proposal.create!(
            projekt_phase: context[2],
            geozone: context[1],
            responsible_name: 'John Doe',
            admin_accepted: true,
            resource_terms: true,
            title: 'Show Proposal',
            description: 'Desc'
          )
        end
        let(:id) { record.id }

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     proposal: { type: :object }
                   },
                   required: ['proposal']
                 }
               },
               required: ['data']

        run_test!
      end

      response '404', 'proposal not found' do
        let(:id) { 999_999 }
        run_test!
      end
    end

    patch 'Update a proposal' do
      tags 'Proposals'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]

      parameter name: :proposal, in: :body, description: 'Attributes to update on the proposal', schema: {
        type: :object,
        properties: {
          proposal: {
            type: :object,
            properties: {
              title: { type: :string }
            }
          }
        }
      }

      response '200', 'proposal updated' do
        let!(:context) { create_phase_with_context }
        let!(:record) do
          Proposal.create!(
            projekt_phase: context[2],
            geozone: context[1],
            responsible_name: 'John Doe',
            admin_accepted: true,
            resource_terms: true,
            title: 'Old Title',
            description: 'Desc'
          )
        end
        let(:id) { record.id }
        let(:proposal) do
          {
            proposal: {
              title: 'Updated Title'
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     proposal: { type: :object }
                   },
                   required: ['proposal']
                 }
               },
               required: ['data']

        run_test!
      end

      response '422', 'invalid request' do
        let!(:context) { create_phase_with_context }
        let!(:record) do
          Proposal.create!(
            projekt_phase: context[2],
            geozone: context[1],
            responsible_name: 'John Doe',
            admin_accepted: true,
            resource_terms: true,
            title: 'Old Title',
            description: 'Desc'
          )
        end
        let(:id) { record.id }
        let(:proposal) do
          {
            proposal: {
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

    delete 'Delete a proposal' do
      tags 'Proposals'
      produces 'application/json'
      security [bearer_auth: []]

      response '200', 'proposal deleted' do
        let!(:context) { create_phase_with_context }
        let!(:record) do
          Proposal.create!(
            projekt_phase: context[2],
            geozone: context[1],
            responsible_name: 'John Doe',
            admin_accepted: true,
            resource_terms: true,
            title: 'To Delete',
            description: 'Desc'
          )
        end
        let(:id) { record.id }

        schema type: :object,
               properties: {
                 message: { type: :string }
               },
               required: ['message']

        run_test!
      end

      response '404', 'proposal not found' do
        let(:id) { 999_999 }
        run_test!
      end

      response '422', 'unable to delete proposal' do
        let!(:context) { create_phase_with_context }
        let!(:record) do
          Proposal.create!(
            projekt_phase: context[2],
            geozone: context[1],
            responsible_name: 'John Doe',
            admin_accepted: true,
            resource_terms: true,
            title: 'Cannot Delete',
            description: 'Desc'
          )
        end
        let(:id) { record.id }

        schema type: :object,
               properties: {
                 error: {
                   type: :object,
                   properties: {
                     messages: { type: :object }
                   }
                 }
               }

        before do
          allow_any_instance_of(Proposal).to receive(:destroy).and_return(false)
          errors_mock = double('errors').as_null_object
          allow(errors_mock).to receive(:messages).and_return({ base: ['Cannot delete proposal'] })
          allow_any_instance_of(Proposal).to receive(:errors).and_return(errors_mock)
        end

        run_test!
      end
    end
  end
end


