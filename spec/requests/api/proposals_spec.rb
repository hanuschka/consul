# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Proposals API', type: :request, openapi_spec: 'v1/swagger.yaml' do
  let!(:api_client) { ApiClient.create!(name: 'Test Client', registration_status: :registered, access_level: :admin).tap(&:reload) }
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
            proposal = Proposal.new(
              author: api_client.user,
              projekt_phase: phase,
              geozone: geozone,
              responsible_name: 'John Doe',
              admin_accepted: true,
              resource_terms: true,
              translations_attributes: [
                {
                  locale: 'en',
                  title: "Proposal #{i + 1}",
                  description: "Description #{i + 1}"
                }
              ]
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
                     proposals: { type: :array, items: { type: :object } }
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
                     messages: { type: :string }
                   }
                 }
               }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['type']).to eq('forbidden')
        end
      end

      response '200', 'proposals found with public_data access' do
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
              translations_attributes: [
                {
                  locale: 'en',
                  title: "Proposal #{i + 1}",
                  description: "Description #{i + 1}"
                }
              ]
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
              responsible_name: 'Jane Smith',
              geozone_id: geozone_id,
              resource_terms: true,
              translations_attributes: [
                {
                  locale: 'en',
                  title: 'New Proposal',
                  description: 'A meaningful description'
                }
              ]
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
              responsible_name: '',
              geozone_id: nil,
              resource_terms: false,
              translations_attributes: [
                {
                  locale: 'en',
                  title: '',
                  description: ''
                }
              ]
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
                     messages: { type: :string }
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
          # Small valid PNG image in base64 (1x1 transparent pixel)
          base64_png = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=='
          {
            proposal: {
              responsible_name: 'Jane Smith',
              geozone_id: geozone_id,
              resource_terms: true,
              image: {
                title: 'Proposal Cover Image',
                base64data: base64_png
              },
              translations_attributes: [
                {
                  locale: 'en',
                  title: 'Proposal with Image',
                  description: 'A proposal created with an image'
                }
              ]
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

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']['proposal']).to be_present
          expect(response.status).to eq(201)
        end
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
          proposal = Proposal.new(
            author: api_client.user,
            projekt_phase: context[2],
            geozone: context[1],
            responsible_name: 'John Doe',
            admin_accepted: true,
            resource_terms: true,
            translations_attributes: [
              {
                locale: 'en',
                title: 'Show Proposal',
                description: 'Desc'
              }
            ]
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
            translations_attributes: [
              {
                locale: 'en',
                title: 'Show Proposal',
                description: 'Desc'
              }
            ]
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
                     messages: { type: :string }
                   }
                 }
               }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['type']).to eq('forbidden')
        end
      end

      response '200', 'proposal found with public_data access' do
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
            translations_attributes: [
              {
                locale: 'en',
                title: 'Show Proposal',
                description: 'Desc'
              }
            ]
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
                     proposal: { type: :object }
                   },
                   required: ['proposal']
                 }
               },
               required: ['data']

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
          proposal = Proposal.new(
            author: api_client.user,
            projekt_phase: context[2],
            geozone: context[1],
            responsible_name: 'John Doe',
            admin_accepted: true,
            resource_terms: true,
            translations_attributes: [
              {
                locale: 'en',
                title: 'Old Title',
                description: 'Desc'
              }
            ]
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
          proposal = Proposal.new(
            author: api_client.user,
            projekt_phase: context[2],
            geozone: context[1],
            responsible_name: 'John Doe',
            admin_accepted: true,
            resource_terms: true,
            translations_attributes: [
              {
                locale: 'en',
                title: 'Old Title',
                description: 'Desc'
              }
            ]
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
            translations_attributes: [
              {
                locale: 'en',
                title: 'Old Title',
                description: 'Desc'
              }
            ]
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
                     messages: { type: :string }
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
            translations_attributes: [
              {
                locale: 'en',
                title: 'Old Title',
                description: 'Desc'
              }
            ]
          )
          proposal.save!
          proposal
        end
        let(:id) { record.id }
        let(:proposal) do
          # Small valid PNG image in base64 (1x1 transparent pixel)
          base64_png = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=='
          {
            proposal: {
              title: 'Updated with Image',
              image: {
                title: 'postman title',
                attachment: base64_png
              }
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

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']['proposal']).to be_present
          expect(response.status).to eq(200)
        end
      end
    end

    delete 'Delete a proposal' do
      tags 'Proposals'
      produces 'application/json'
      security [bearer_auth: []]

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
            translations_attributes: [
              {
                locale: 'en',
                title: 'To Delete',
                description: 'Desc'
              }
            ]
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
            translations_attributes: [
              {
                locale: 'en',
                title: 'Cannot Delete',
                description: 'Desc'
              }
            ]
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
            translations_attributes: [
              {
                locale: 'en',
                title: 'To Delete',
                description: 'Desc'
              }
            ]
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
                     messages: { type: :string }
                   }
                 }
               }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['type']).to eq('forbidden')
        end
      end
    end
  end

  path '/api/proposals/{id}/update_image' do
    parameter name: :id, in: :path, type: :integer, description: 'Proposal ID'

    patch 'Update proposal image' do
      tags 'Proposals'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]

      parameter name: :image, in: :body, description: 'Image update payload', schema: {
        type: :object,
        properties: {
          image: {
            type: :object,
            properties: {
              attachment: { type: :string, description: 'Base64-encoded image data' },
              title: { type: :string },
              credits: { type: :string },
              _destroy: { type: :boolean }
            }
          }
        },
        required: ['image']
      }

      response '200', 'image uploaded successfully' do
        before do
          # Create an admin user for image association
          admin_user = User.create!(
            username: 'admin_user',
            email: 'admin@example.com',
            password: 'Password123!',
            password_confirmation: 'Password123!',
            terms_data_protection: true,
            terms_data_storage: true,
            terms_general: true
          )
          Administrator.create!(user: admin_user)
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
            translations_attributes: [
              {
                locale: 'en',
                title: 'Proposal for Image Upload',
                description: 'Desc'
              }
            ]
          )
          proposal.save!
          proposal
        end
        let(:id) { record.id }
        let(:image) do
          # Use a fixture image that meets minimum size requirements (620x390)
          image_path = Rails.root.join('spec', 'fixtures', 'files', 'clippy.jpg')
          base64_image = Base64.encode64(File.read(image_path))
          {
            image: {
              attachment: base64_image,
              title: 'Proposal Cover Image',
              credits: 'Photo by John Doe'
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

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']['proposal']).to be_present
          expect(response.status).to eq(200)
        end
      end

      response '200', 'image deleted successfully' do
        before do
          # Create an admin user for image association
          admin_user = User.create!(
            username: 'admin_user_2',
            email: 'admin2@example.com',
            password: 'Password123!',
            password_confirmation: 'Password123!',
            terms_data_protection: true,
            terms_data_storage: true,
            terms_general: true
          )
          Administrator.create!(user: admin_user)
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
            translations_attributes: [
              {
                locale: 'en',
                title: 'Proposal with Image to Delete',
                description: 'Desc'
              }
            ]
          )
          proposal.save!
          proposal
        end
        let(:id) { record.id }
        let(:image) do
          {
            image: {
              _destroy: true
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

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']['proposal']).to be_present
          expect(response.status).to eq(200)
        end
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
            translations_attributes: [
              {
                locale: 'en',
                title: 'Proposal',
                description: 'Desc'
              }
            ]
          )
          proposal.save!
          proposal
        end
        let(:id) { record.id }
        let(:image) do
          base64_png = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=='
          {
            image: {
              attachment: base64_png,
              title: 'Proposal Cover Image'
            }
          }
        end

        schema type: :object,
               properties: {
                 error: {
                   type: :object,
                   properties: {
                     type: { type: :string },
                     messages: { type: :string }
                   }
                 }
               }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['type']).to eq('forbidden')
        end
      end
    end
  end
end


