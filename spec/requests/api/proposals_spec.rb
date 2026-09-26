# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Proposals API', type: :request, openapi_spec: 'v1/swagger.yaml' do
  let!(:api_client) { create_api_client }
  let(:Authorization) { "Bearer #{api_client.access_token}" }

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
      description "Retrieve all proposals submitted for a specific projekt phase. Proposals are citizen-initiated action items or projects proposed within a participation phase. Access filtering: public_data users automatically see only published (non-draft) and non-archived proposals. The for_public_render parameter is independent and can be used to apply additional filtering. Returns paginated results. #{ApiAccessRequirements::GET_READ_ONLY}"
      parameter name: :sort, in: :query, type: :string, required: false, description: "Sort proposals by. Valid values: 'created_at' (**default**, oldest first), 'hot_score' (trending/most activity), 'confidence_score' (highest confidence first), 'relevance' (most voted first), 'archival_date' (most recently archived first)"
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Pagination page number (**default:** 1)'
      parameter name: :per_page, in: :query, type: :integer, required: false, description: 'Number of items per page (**default:** 500, max: 2000)'
      parameter name: :for_public_render, in: :query, type: :boolean, required: false, description: 'If true, returns only proposals that are publicly visible and ready for rendering on frontend (published, non-archived, non-retired). This filter is independent: public_data users will have discard_draft and discard_archived applied automatically, and can additionally use for_public_render to apply stricter filtering.'

      response '200', 'proposals found and returned' do
        before do
          _projekt, geozone, phase = create_phase_with_context
          2.times do |i|
            proposal = Proposal.new(
              author: api_client.user,
              projekt_phase: phase,
              geozone: geozone,
              responsible_name: 'John Doe',
              admin_accepted: true,
              resource_terms: true,
              title: "Proposal #{i}",
              description: "Description for proposal #{i}"
            )
            proposal.save!
          end
        end

        let(:projekt_phase_id) { ProjektPhase.last.id }

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     proposals: { type: :array, items: { '$ref' => '#/components/schemas/Proposal' } }
                   },
                   required: ['proposals']
                 },
                 pagination: { type: :object }
               },
               required: ['data']

        run_test!
      end

      response '403', 'forbidden - insufficient access' do
        let(:projekt) { Projekt.create!(name: 'Projekt For Proposals') }
        let(:phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::ProposalPhase', active: true) }
        let(:projekt_phase_id) { phase.id }

        before do
          phase # Ensure phase is created
          api_client.update_column(:access_level, nil)
        end

        schema type: :object,
               properties: {
                 error: {
                   type: :object,
                   properties: {
                     type: { type: :string },
                     messages: { type: :array, items: { type: :string } }
                   }
                 }
               }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['type']).to eq('forbidden')
        end
      end

      response '200', 'proposals found with public_data access (published only)' do
        before do
          api_client.update!(access_level: :public_data)
          _projekt, geozone, phase = create_phase_with_context
          2.times do |i|
            proposal = Proposal.new(
              author: api_client.user,
              projekt_phase: phase,
              geozone: geozone,
              responsible_name: 'John Doe',
              admin_accepted: true,
              resource_terms: true,
              title: "Proposal #{i}",
              description: "Description for proposal #{i}",
              published_at: Time.current
            )
            proposal.save!
          end
        end

        let(:projekt_phase_id) { ProjektPhase.last.id }

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     proposals: { type: :array, items: { '$ref' => '#/components/schemas/Proposal' } }
                   },
                   required: ['proposals']
                 },
                 pagination: { type: :object }
               },
               required: ['data']

        run_test!
      end

      response '200', 'proposals found with public_data access (excludes drafts)' do
        before do
          api_client.update!(access_level: :public_data)
          _projekt, geozone, phase = create_phase_with_context
          proposal_published = Proposal.new(
            author: api_client.user,
            projekt_phase: phase,
            geozone: geozone,
            responsible_name: 'John Doe',
            admin_accepted: true,
            resource_terms: true,
            title: 'Published Proposal',
            description: 'Published Description',
            published_at: Time.current
          )
          proposal_published.save!

          proposal_draft = Proposal.new(
            author: api_client.user,
            projekt_phase: phase,
            geozone: geozone,
            responsible_name: 'John Doe',
            admin_accepted: true,
            resource_terms: true,
            title: 'Draft Proposal',
            description: 'Draft Description'
          )
          proposal_draft.save!
        end

        let(:projekt_phase_id) { ProjektPhase.last.id }

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     proposals: { type: :array, items: { '$ref' => '#/components/schemas/Proposal' } }
                   },
                   required: ['proposals']
                 },
                 pagination: { type: :object }
               },
               required: ['data']

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']['proposals'].length).to eq(1)
          expect(data['data']['proposals'][0]['title']).to eq('Published Proposal')
        end
      end

      response '200', 'proposals sorted by hot_score' do
        before do
          _projekt, geozone, phase = create_phase_with_context
          2.times do |i|
            proposal = Proposal.new(
              author: api_client.user,
              projekt_phase: phase,
              geozone: geozone,
              responsible_name: 'John Doe',
              admin_accepted: true,
              resource_terms: true,
              title: "Proposal #{i}",
              description: "Description for proposal #{i}"
            )
            proposal.save!
          end
        end

        let(:projekt_phase_id) { ProjektPhase.last.id }
        let(:sort) { 'hot_score' }

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     proposals: { type: :array, items: { '$ref' => '#/components/schemas/Proposal' } }
                   },
                   required: ['proposals']
                 },
                 pagination: { type: :object }
               },
               required: ['data']

        run_test!
      end

      unauthorized_response { let(:projekt_phase_id) { 1 } }
    end

    post 'Create a proposal' do
      tags 'Proposals'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Submit a new proposal within a projekt phase. Proposals are citizen-initiated action items that require a responsible party, geozone location, and acceptance of terms. Proposals go through an admin review process before being published. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      parameter name: :proposal, in: :body, description: 'Proposal submission with required title, description, responsible party, geozone, and terms acceptance', schema: Schemas::CommentsProposals::PROPOSAL_CREATE_PARAMS

      response '201', 'proposal created' do
        let!(:context) { create_phase_with_context }
        let(:projekt_phase_id) { context[2].id }
        let(:geozone_id) { context[1].id }
        let(:proposal) do
          {
            proposal: {
              responsible_name: 'Jane Smith',
              geozone_id: geozone_id,
              resource_terms: true,
              title: 'New Proposal',
              description: 'A meaningful description for the proposal'
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     proposal: { '$ref' => '#/components/schemas/Proposal' }
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

      response '403', 'forbidden - admin access required' do
        before do
          api_client.update!(access_level: :public_data)
        end

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
                 error: {
                   type: :object,
                   properties: {
                     type: { type: :string },
                     messages: { type: :array, items: { type: :string } }
                   }
                 }
               }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['type']).to eq('forbidden')
        end
      end

      response '201', 'proposal created with base64 image' do
        let!(:context) { create_phase_with_context }
        let(:projekt_phase_id) { context[2].id }
        let(:geozone_id) { context[1].id }
        let(:proposal) do
          {
            proposal: {
              responsible_name: 'Jane Smith',
              geozone_id: geozone_id,
              resource_terms: true,
              title: 'Proposal with Image',
              description: 'A proposal with an image attachment',
              image: {
                title: 'Proposal Cover Image',
                base64data: base64_fixture('1x1.png')
              }
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     proposal: { '$ref' => '#/components/schemas/Proposal' }
                   },
                   required: ['proposal']
                 }
               },
               required: ['data']

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']['proposal']).to be_present
          expect(response.status).to eq(201)
        end
      end

      response '201', 'proposal created as draft (published: false)' do
        let!(:context) { create_phase_with_context }
        let(:projekt_phase_id) { context[2].id }
        let(:geozone_id) { context[1].id }
        let(:proposal) do
          {
            proposal: {
              responsible_name: 'Jane Smith',
              geozone_id: geozone_id,
              resource_terms: true,
              title: 'Draft Proposal',
              description: 'A proposal that should remain unpublished',
              published: false
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     proposal: { '$ref' => '#/components/schemas/Proposal' }
                   },
                   required: ['proposal']
                 }
               },
               required: ['data']

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']['proposal']).to be_present
          expect(Proposal.unscoped.find(data['data']['proposal']['id']).published?).to eq(false)
        end
      end

      unauthorized_response { let(:projekt_phase_id) { 1 } }
    end
  end

  path '/api/proposals' do
    get 'List all proposals' do
      tags 'Proposals'
      produces 'application/json'
      security [bearer_auth: []]
      description "Retrieve a paginated list of all proposals across all projekt phases. Access filtering: public_data users automatically see only published (non-draft) and non-archived proposals. The for_public_render parameter is independent and can be used to apply additional filtering. #{ApiAccessRequirements::GET_READ_ONLY}"
      parameter name: :page, in: :query, type: :integer, description: 'Pagination page number (**default:** 1)', required: false
      parameter name: :per_page, in: :query, type: :integer, description: 'Number of items per page (**default:** 500, max: 2000)', required: false
      parameter name: :for_public_render, in: :query, type: :boolean, required: false, description: 'If true, returns only proposals that are publicly visible and ready for rendering on frontend (published, non-archived, non-retired). This filter is independent: public_data users will have discard_draft and discard_archived applied automatically, and can additionally use for_public_render to apply stricter filtering.'

      response '200', 'proposals found' do
        let(:projekt1) { Projekt.create!(name: 'Projekt 1') }
        let(:projekt2) { Projekt.create!(name: 'Projekt 2') }
        let(:geozone) { Geozone.create!(name: "Zone #{SecureRandom.hex(2)}") }
        let(:proposal_phase1) { projekt1.projekt_phases.create!(type: 'ProjektPhase::ProposalPhase', active: true) }
        let(:proposal_phase2) { projekt2.projekt_phases.create!(type: 'ProjektPhase::ProposalPhase', active: true) }

        before do
          proposal1 = Proposal.new(
            author: api_client.user,
            projekt_phase: proposal_phase1,
            geozone: geozone,
            responsible_name: 'John Doe',
            admin_accepted: true,
            resource_terms: true,
            title: 'Proposal 1',
            description: 'Description for proposal 1'
          )
          proposal1.save!

          proposal2 = Proposal.new(
            author: api_client.user,
            projekt_phase: proposal_phase2,
            geozone: geozone,
            responsible_name: 'Jane Doe',
            admin_accepted: true,
            resource_terms: true,
            title: 'Proposal 2',
            description: 'Description for proposal 2'
          )
          proposal2.save!
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     proposals: {
                       type: :array,
                       items: { type: :object }
                     }
                   },
                   required: ['proposals']
                 },
                 pagination: Schemas::Miscellaneous::PAGINATION_RESPONSE_SCHEMA
               },
               required: ['data']

        run_test!
      end

      unauthorized_response
    end
  end

  path '/api/proposals/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'Proposal ID'

    get 'Retrieve a proposal' do
      tags 'Proposals'
      produces 'application/json'
      security [bearer_auth: []]
      description "Retrieve a single proposal by ID with all its details. Users with public_data access can only view published (non-draft), non-archived proposals. Admin users can view all proposals. #{ApiAccessRequirements::GET_READ_ONLY}"

      response '200', 'proposal found' do
        let!(:context) { create_phase_with_context }
        let!(:record) do
          proposal = Proposal.new(
            author: api_client.user,
            projekt_phase: context[2],
            geozone: context[1],
            responsible_name: 'John Doe',
            admin_accepted: true,
            resource_terms: true,
            title: 'Test Proposal',
            description: 'Test Description'
          )
          proposal.save!
          proposal
        end
        let(:id) { record.id }

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     proposal: { '$ref' => '#/components/schemas/Proposal' }
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

      response '403', 'forbidden - insufficient access' do
        let!(:context) { create_phase_with_context }
        let!(:record) do
          proposal = Proposal.new(
            author: api_client.user,
            projekt_phase: context[2],
            geozone: context[1],
            responsible_name: 'John Doe',
            admin_accepted: true,
            resource_terms: true,
            title: 'Test Proposal',
            description: 'Test Description'
          )
          proposal.save!
          proposal
        end
        let(:id) { record.id }
        before do
          api_client.update_column(:access_level, nil)
        end

        schema type: :object,
               properties: {
                 error: {
                   type: :object,
                   properties: {
                     type: { type: :string },
                     messages: { type: :array, items: { type: :string } }
                   }
                 }
               }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['type']).to eq('forbidden')
        end
      end

      response '200', 'proposal found with public_data access (published only)' do
        before do
          api_client.update!(access_level: :public_data)
        end

        let!(:context) { create_phase_with_context }
        let!(:record) do
          proposal = Proposal.new(
            author: api_client.user,
            projekt_phase: context[2],
            geozone: context[1],
            responsible_name: 'John Doe',
            admin_accepted: true,
            resource_terms: true,
            title: 'Test Proposal',
            description: 'Test Description',
            published_at: Time.current
          )
          proposal.save!
          proposal
        end
        let(:id) { record.id }

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     proposal: { '$ref' => '#/components/schemas/Proposal' }
                   },
                   required: ['proposal']
                 }
               },
               required: ['data']

        run_test!
      end

      response '403', 'forbidden - public_data cannot access draft proposal' do
        before do
          api_client.update!(access_level: :public_data)
        end

        let!(:context) { create_phase_with_context }
        let!(:record) do
          proposal = Proposal.new(
            author: api_client.user,
            projekt_phase: context[2],
            geozone: context[1],
            responsible_name: 'John Doe',
            admin_accepted: true,
            resource_terms: true,
            title: 'Draft Proposal',
            description: 'Draft Description'
          )
          proposal.save!
          proposal
        end
        let(:id) { record.id }

        schema type: :object,
               properties: {
                 error: {
                   type: :object,
                   properties: {
                     type: { type: :string },
                     messages: { type: :array, items: { type: :string } }
                   }
                 }
               }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['type']).to eq('forbidden')
        end
      end

      unauthorized_response { let(:id) { 1 } }
    end

    patch 'Update a proposal' do
      tags 'Proposals'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Update an existing proposal. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      parameter name: :proposal, in: :body, description: 'Attributes to update on the proposal', schema: Schemas::CommentsProposals::PROPOSAL_UPDATE_PARAMS

      response '200', 'proposal updated' do
        let!(:context) { create_phase_with_context }
        let!(:record) do
          proposal = Proposal.new(
            author: api_client.user,
            projekt_phase: context[2],
            geozone: context[1],
            responsible_name: 'John Doe',
            admin_accepted: true,
            resource_terms: true,
            title: 'Test Proposal',
            description: 'Test Description'
          )
          proposal.save!
          proposal
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
                     proposal: { '$ref' => '#/components/schemas/Proposal' }
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
          proposal = Proposal.new(
            author: api_client.user,
            projekt_phase: context[2],
            geozone: context[1],
            responsible_name: 'John Doe',
            admin_accepted: true,
            resource_terms: true,
            title: 'Test Proposal',
            description: 'Test Description'
          )
          proposal.save!
          proposal
        end
        let(:id) { record.id }
        let(:proposal) do
          {
            proposal: {
              title: ''
            }
          }
        end

        before do
          allow_any_instance_of(Proposal).to receive(:save).and_return(false)
          errors_mock = double('errors').as_null_object
          allow(errors_mock).to receive(:full_messages).and_return(['Title can\'t be blank'])
          allow_any_instance_of(Proposal).to receive(:errors).and_return(errors_mock)
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

      response '403', 'forbidden - admin access required' do
        before do
          api_client.update!(access_level: :public_data)
        end

        let!(:context) { create_phase_with_context }
        let!(:record) do
          proposal = Proposal.new(
            author: api_client.user,
            projekt_phase: context[2],
            geozone: context[1],
            responsible_name: 'John Doe',
            admin_accepted: true,
            resource_terms: true,
            title: 'Test Proposal',
            description: 'Test Description'
          )
          proposal.save!
          proposal
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
                 error: {
                   type: :object,
                   properties: {
                     type: { type: :string },
                     messages: { type: :array, items: { type: :string } }
                   }
                 }
               }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['type']).to eq('forbidden')
        end
      end

      response '200', 'proposal updated with base64 image' do
        let!(:context) { create_phase_with_context }
        let!(:record) do
          proposal = Proposal.new(
            author: api_client.user,
            projekt_phase: context[2],
            geozone: context[1],
            responsible_name: 'John Doe',
            admin_accepted: true,
            resource_terms: true,
            title: 'Test Proposal',
            description: 'Test Description'
          )
          proposal.save!
          proposal
        end
        let(:id) { record.id }
        let(:proposal) do
          {
            proposal: {
              title: 'Updated with Image',
              image: {
                title: 'postman title',
                attachment: base64_fixture('1x1.png')
              }
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     proposal: { '$ref' => '#/components/schemas/Proposal' }
                   },
                   required: ['proposal']
                 }
               },
               required: ['data']

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']['proposal']).to be_present
          expect(response.status).to eq(200)
        end
      end

      unauthorized_response { let(:id) { 1 } }
    end

    delete 'Delete a proposal' do
      tags 'Proposals'
      produces 'application/json'
      security [bearer_auth: []]
      description "Delete an existing proposal. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      response '200', 'proposal deleted' do
        let!(:context) { create_phase_with_context }
        let!(:record) do
          proposal = Proposal.new(
            author: api_client.user,
            projekt_phase: context[2],
            geozone: context[1],
            responsible_name: 'John Doe',
            admin_accepted: true,
            resource_terms: true,
            title: 'Test Proposal',
            description: 'Test Description'
          )
          proposal.save!
          proposal
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
          proposal = Proposal.new(
            author: api_client.user,
            projekt_phase: context[2],
            geozone: context[1],
            responsible_name: 'John Doe',
            admin_accepted: true,
            resource_terms: true,
            title: 'Test Proposal',
            description: 'Test Description'
          )
          proposal.save!
          proposal
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

      response '403', 'forbidden - admin access required' do
        before do
          api_client.update!(access_level: :public_data)
        end

        let!(:context) { create_phase_with_context }
        let!(:record) do
          proposal = Proposal.new(
            author: api_client.user,
            projekt_phase: context[2],
            geozone: context[1],
            responsible_name: 'John Doe',
            admin_accepted: true,
            resource_terms: true,
            title: 'Test Proposal',
            description: 'Test Description'
          )
          proposal.save!
          proposal
        end
        let(:id) { record.id }

        schema type: :object,
               properties: {
                 error: {
                   type: :object,
                   properties: {
                     type: { type: :string },
                     messages: { type: :array, items: { type: :string } }
                   }
                 }
               }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['type']).to eq('forbidden')
        end
      end

      unauthorized_response { let(:id) { 1 } }
    end
  end

  path '/api/proposals/{id}/publish' do
    parameter name: :id, in: :path, type: :integer, description: 'Proposal ID'

    patch 'Publish a proposal' do
      tags 'Proposals'
      produces 'application/json'
      security [bearer_auth: []]
      description "Publish a previously created proposal, setting its published_at timestamp and making it visible in the frontend. Idempotent: publishing an already-published proposal returns it unchanged without re-sending notifications. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      response '200', 'proposal published' do
        let!(:context) { create_phase_with_context }
        let!(:record) do
          proposal = Proposal.new(
            author: api_client.user,
            projekt_phase: context[2],
            geozone: context[1],
            responsible_name: 'John Doe',
            admin_accepted: true,
            resource_terms: true,
            title: 'Draft Proposal',
            description: 'Draft Description'
          )
          proposal.save!
          proposal
        end
        let(:id) { record.id }

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     proposal: { '$ref' => '#/components/schemas/Proposal' }
                   },
                   required: ['proposal']
                 }
               },
               required: ['data']

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']['proposal']).to be_present
          expect(record.reload.published?).to eq(true)
        end
      end

      response '404', 'proposal not found' do
        let(:id) { 999_999 }
        run_test!
      end

      response '403', 'forbidden - admin access required' do
        before do
          api_client.update!(access_level: :public_data)
        end

        let!(:context) { create_phase_with_context }
        let!(:record) do
          proposal = Proposal.new(
            author: api_client.user,
            projekt_phase: context[2],
            geozone: context[1],
            responsible_name: 'John Doe',
            admin_accepted: true,
            resource_terms: true,
            title: 'Draft Proposal',
            description: 'Draft Description'
          )
          proposal.save!
          proposal
        end
        let(:id) { record.id }

        schema type: :object,
               properties: {
                 error: {
                   type: :object,
                   properties: {
                     type: { type: :string },
                     messages: { type: :array, items: { type: :string } }
                   }
                 }
               }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['type']).to eq('forbidden')
        end
      end

      unauthorized_response { let(:id) { 1 } }
    end
  end
end


