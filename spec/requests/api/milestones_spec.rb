# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Milestones API', type: :request do
  # Authentication setup - create an ApiClient with an auth_token
  let!(:api_client) { ApiClient.create!(name: 'Test Client', registration_status: :registered, access_level: :admin) }
  let(:Authorization) { "Bearer #{api_client.auth_token}" }

  path '/api/projekt_phases/{projekt_phase_id}/milestones' do
    parameter name: :projekt_phase_id, in: :path, type: :integer, description: 'Projekt Phase ID'

    get 'List all milestones' do
      tags 'Milestones'
      produces 'application/json'
      security [bearer_auth: []]
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :per_page, in: :query, type: :integer, required: false, description: 'Items per page (default 100)'

      response '200', 'milestones found' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:projekt_phase_id) { ProjektPhase::MilestonePhase.create!(projekt: test_projekt).id }

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     milestones: {
                       type: :array,
                       items: { type: :object }
                     }
                   },
                   required: ['milestones']
                 },
                 pagination: {
                   type: :object,
                   properties: {
                     current_page: { type: :integer },
                     total_pages: { type: :integer },
                     total_count: { type: :integer },
                     per_page: { type: :integer }
                   }
                 }
               },
               required: ['data', 'pagination']

        run_test!
      end

      response '403', 'forbidden - insufficient access' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:projekt_phase_id) { ProjektPhase::MilestonePhase.create!(projekt: test_projekt).id }

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
    end

    post 'Create a milestone' do
      tags 'Milestones'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]

      parameter name: :milestone, in: :body, description: 'Milestone creation payload', schema: {
        type: :object,
        properties: {
          milestone: {
            type: :object,
            properties: {
              publication_date: { type: :string, format: :date },
              status_id: { type: :integer }
            }
          }
        },
        required: ['milestone']
      }

      response '201', 'milestone created' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:projekt_phase_id) { ProjektPhase::MilestonePhase.create!(projekt: test_projekt).id }
        let(:milestone) do
          {
            milestone: {
              publication_date: Date.today.to_s,
              status_id: 1
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     milestone: { type: :object }
                   },
                   required: ['milestone']
                 }
               },
               required: ['data']

        run_test!
      end

      response '422', 'invalid request' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:projekt_phase_id) { ProjektPhase::MilestonePhase.create!(projekt: test_projekt).id }
        let(:milestone) do
          {
            milestone: {
              publication_date: Date.today.to_s
            }
          }
        end

        schema type: :object,
               properties: {
                 error: {
                   type: :object,
                   properties: {
                     messages: { type: :array }
                   }
                 }
               }

        before do
          allow_any_instance_of(Milestone).to receive(:save).and_return(false)
          errors_mock = double('errors').as_null_object
          allow(errors_mock).to receive(:full_messages).and_return(['Invalid milestone'])
          allow_any_instance_of(Milestone).to receive(:errors).and_return(errors_mock)
        end

        run_test!
      end

      response '403', 'forbidden - admin access required' do
        before do
          api_client.update!(access_level: :public_data)
        end

        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:projekt_phase_id) { ProjektPhase::MilestonePhase.create!(projekt: test_projekt).id }
        let(:milestone) do
          {
            milestone: {
              publication_date: Date.today.to_s
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
    end
  end

  path '/api/milestones/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'Milestone ID'

    get 'Retrieve a milestone' do
      tags 'Milestones'
      produces 'application/json'
      security [bearer_auth: []]

      response '200', 'milestone found' do
        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     milestone: { type: :object }
                   },
                   required: ['milestone']
                 }
               },
               required: ['data']

        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:projekt_phase) { ProjektPhase::MilestonePhase.create!(projekt: test_projekt) }
        let(:test_milestone) { Milestone.create!(milestoneable: projekt_phase, publication_date: Date.today, description_en: 'Test milestone') }
        let(:id) { test_milestone.id }

        run_test!
      end

      response '404', 'milestone not found' do
        let(:id) { 999999 }

        run_test!
      end

      response '403', 'forbidden - insufficient access' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:projekt_phase) { ProjektPhase::MilestonePhase.create!(projekt: test_projekt) }
        let(:test_milestone) { Milestone.create!(milestoneable: projekt_phase, publication_date: Date.today, description_en: 'Test milestone') }
        let(:id) { test_milestone.id }

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
    end

    patch 'Update a milestone' do
      tags 'Milestones'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]

      parameter name: :milestone, in: :body, description: 'Attributes to update on the milestone', schema: {
        type: :object,
        properties: {
          milestone: {
            type: :object,
            properties: {
              publication_date: { type: :string, format: :date },
              status_id: { type: :integer }
            }
          }
        },
        required: ['milestone']
      }

      response '200', 'milestone updated' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:projekt_phase) { ProjektPhase::MilestonePhase.create!(projekt: test_projekt) }
        let(:test_milestone) { Milestone.create!(milestoneable: projekt_phase, publication_date: Date.today, description_en: 'Test milestone') }
        let(:id) { test_milestone.id }
        let(:milestone) do
          {
            milestone: {
              publication_date: (Date.today + 1).to_s
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     milestone: { type: :object }
                   },
                   required: ['milestone']
                 }
               },
               required: ['data']

        run_test!
      end

      response '404', 'milestone not found' do
        let(:id) { 999999 }
        let(:milestone) do
          {
            milestone: {
              publication_date: Date.today.to_s
            }
          }
        end

        run_test!
      end

      response '422', 'invalid request' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:projekt_phase) { ProjektPhase::MilestonePhase.create!(projekt: test_projekt) }
        let(:test_milestone) { Milestone.create!(milestoneable: projekt_phase, publication_date: Date.today, description_en: 'Test milestone') }
        let(:id) { test_milestone.id }
        let(:milestone) do
          {
            milestone: {
              publication_date: (Date.today + 1).to_s
            }
          }
        end

        schema type: :object,
               properties: {
                 error: {
                   type: :object,
                   properties: {
                     messages: { type: :array }
                   }
                 }
               }

        before do
          allow_any_instance_of(Milestone).to receive(:update).and_return(false)
          errors_mock = double('errors').as_null_object
          allow(errors_mock).to receive(:full_messages).and_return(['Update failed'])
          allow_any_instance_of(Milestone).to receive(:errors).and_return(errors_mock)
        end

        run_test!
      end

      response '403', 'forbidden - admin access required' do
        before do
          api_client.update!(access_level: :public_data)
        end

        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:projekt_phase) { ProjektPhase::MilestonePhase.create!(projekt: test_projekt) }
        let(:test_milestone) { Milestone.create!(milestoneable: projekt_phase, publication_date: Date.today, description_en: 'Test milestone') }
        let(:id) { test_milestone.id }
        let(:milestone) do
          {
            milestone: {
              publication_date: (Date.today + 1).to_s
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
    end

    delete 'Delete a milestone' do
      tags 'Milestones'
      produces 'application/json'
      security [bearer_auth: []]

      response '200', 'milestone deleted' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:projekt_phase) { ProjektPhase::MilestonePhase.create!(projekt: test_projekt) }
        let(:test_milestone) { Milestone.create!(milestoneable: projekt_phase, publication_date: Date.today, description_en: 'Test milestone') }
        let(:id) { test_milestone.id }

        schema type: :object,
               properties: {
                 message: { type: :string }
               },
               required: ['message']

        run_test!
      end

      response '404', 'milestone not found' do
        let(:id) { 999999 }

        run_test!
      end

      response '422', 'unable to delete milestone' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:projekt_phase) { ProjektPhase::MilestonePhase.create!(projekt: test_projekt) }
        let(:test_milestone) { Milestone.create!(milestoneable: projekt_phase, publication_date: Date.today, description_en: 'Test milestone') }
        let(:id) { test_milestone.id }

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
          errors_mock = double('errors').as_null_object
          allow(errors_mock).to receive(:messages).and_return({ base: ['Cannot delete milestone'] })

          allow_any_instance_of(Milestone).to receive(:destroy).and_return(false)
          allow_any_instance_of(Milestone).to receive(:errors).and_return(errors_mock)
        end

        run_test!
      end

      response '403', 'forbidden - admin access required' do
        before do
          api_client.update!(access_level: :public_data)
        end

        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:projekt_phase) { ProjektPhase::MilestonePhase.create!(projekt: test_projekt) }
        let(:test_milestone) { Milestone.create!(milestoneable: projekt_phase, publication_date: Date.today, description_en: 'Test milestone') }
        let(:id) { test_milestone.id }

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
    end
  end
end
