# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Projekt Phases API', type: :request, openapi_spec: 'v1/swagger.yaml' do
  let!(:api_client) { create_api_client }
  let(:Authorization) { "Bearer #{api_client.access_token}" }

let(:existing_projekt) { Projekt.create!(name: "Projekt for phases") }
let(:existing_projekt_phase) do
  existing_projekt.projekt_phases.create!(type: 'ProjektPhase::EventPhase', active: true)
end

  path '/api/projekts/{projekt_id}/projekt_phases' do
    parameter name: :projekt_id, in: :path, type: :integer, description: 'Projekt ID'

    get 'List projekt phases for a projekt' do
      tags 'Projekt Phases'
      produces 'application/json'
      security [bearer_auth: []]
      description "Retrieve all phases defined for a specific projekt. Phases define different stages of participation (comments, proposals, voting, budgeting, etc.) with their own active/inactive periods, visibility settings, and restrictions. Returns full details including phase type, dates, and configuration. #{ApiAccessRequirements::GET_READ_ONLY}"
      parameter name: :page, in: :query, type: :integer, description: 'Pagination page number (**default:** 1)', required: false
      parameter name: :per_page, in: :query, type: :integer, description: 'Number of items per page (**default:** 500, max: 2000)', required: false

      response '200', 'projekt phases found and returned (admin sees all)' do
        let(:projekt) { Projekt.create!(name: 'Projekt With Phases') }
        let(:projekt_id) { projekt.id }

        before do
          projekt.projekt_phases.create!(type: 'ProjektPhase::CommentPhase', active: true, frontend_visibility: true, phase_tab_name: 'Comments')
          projekt.projekt_phases.create!(type: 'ProjektPhase::QuestionPhase', active: false, frontend_visibility: false, phase_tab_name: 'Questions')
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     projekt_phases: {
                       type: :array,
                       items: { '$ref' => '#/components/schemas/ProjektPhase' }
                     }
                   },
                   required: ['projekt_phases']
                 },
                 pagination: {
                   type: :object,
                   properties: {
                     current_page: { type: :integer },
                     total_pages: { type: :integer },
                     total_count: { type: :integer },
                     per_page: { type: :integer }
                   },
                   required: ['current_page', 'total_pages', 'total_count', 'per_page']
                 }
               },
               required: ['data', 'pagination']

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']['projekt_phases'].length).to eq(2)
        end
      end

      response '200', 'projekt phases found and returned (public_data sees only visible/active)' do
        let(:projekt) { Projekt.create!(name: 'Projekt With Phases', activated: true) }
        let(:projekt_id) { projekt.id }

        before do
          api_client.update!(access_level: :public_data)
          projekt.projekt_phases.create!(type: 'ProjektPhase::CommentPhase', active: true, frontend_visibility: true, phase_tab_name: 'Comments')
          projekt.projekt_phases.create!(type: 'ProjektPhase::QuestionPhase', active: false, frontend_visibility: false, phase_tab_name: 'Questions')
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     projekt_phases: {
                       type: :array,
                       items: { '$ref' => '#/components/schemas/ProjektPhase' }
                     }
                   },
                   required: ['projekt_phases']
                 },
                 pagination: {
                   type: :object,
                   properties: {
                     current_page: { type: :integer },
                     total_pages: { type: :integer },
                     total_count: { type: :integer },
                     per_page: { type: :integer }
                   },
                   required: ['current_page', 'total_pages', 'total_count', 'per_page']
                 }
               },
               required: ['data', 'pagination']

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']['projekt_phases'].length).to eq(1)
          expect(data['data']['projekt_phases'][0]['phase_tab_name']).to eq('Comments')
        end
      end

      unauthorized_response { let(:projekt_id) { 1 } }
    end

    post 'Create a projekt phase' do
      tags 'Projekt Phases'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Create a new phase for a projekt. Phases are time-bounded periods that enable specific types of participation (comments, proposals, voting, etc.). Supports restrictions by geozone, age range, user status, and demographic groups. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      parameter name: :projekt_phase, in: :body, description: 'Phase configuration with required type and optional start/end dates, visibility, restrictions, texts per language and settings', schema: {
        type: :object,
        properties: {
          projekt_phase: { '$ref' => '#/components/schemas/ProjektPhaseRequestParams' }
        },
        required: ['projekt_phase']
      }

      response '201', 'projekt phase created' do
        let(:projekt) { Projekt.create!(name: 'Projekt For Phase Create') }
        let(:projekt_id) { projekt.id }
        let(:projekt_phase) do
          {
            projekt_phase: {
              type: 'ProjektPhase::CommentPhase',
              active: true,
              frontend_visibility: true,
              phase_tab_name: 'Discussion'
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     projekt_phase: { '$ref' => '#/components/schemas/ProjektPhase' }
                   },
                   required: ['projekt_phase']
                 }
               },
               required: ['data']

        run_test!
      end

      response '422', 'invalid projekt phase type' do
        let(:projekt) { Projekt.create!(name: 'Projekt For Phase Create') }
        let(:projekt_id) { projekt.id }
        let(:projekt_phase) do
          {
            projekt_phase: {
              type: 'InvalidPhaseType',
              active: true,
              frontend_visibility: true
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

      response '422', 'missing required type field' do
        let(:projekt) { Projekt.create!(name: 'Projekt For Phase Create') }
        let(:projekt_id) { projekt.id }
        let(:projekt_phase) do
          {
            projekt_phase: {
              active: true,
              frontend_visibility: true
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

      unauthorized_response { let(:projekt_id) { 1 } }
      forbidden_response { let(:projekt_id) { existing_projekt.id } }
    end
  end

  path '/api/projekt_phases/{id}/update_setting' do
    parameter name: :id, in: :path, type: :integer, description: 'Projekt Phase ID'

    patch 'Update a projekt phase setting by key' do
      tags 'Projekt Phases'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Update one setting of a projekt phase. Only the keys the phase's type lists " \
                  "(see `ProjektPhaseSettingsUpdate` for all keys and their types) can be changed; " \
                  "unknown keys answer 404 and are never created. Switches take `true`/`false` " \
                  "(the stored forms `\"active\"`/`\"\"` are accepted as well). Every change is " \
                  "recorded in the audit trail. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      parameter name: :projekt_phase_setting, in: :body, description: 'Setting key and its new value', schema: {
        type: :object,
        properties: {
          projekt_phase_setting: {
            type: :object,
            properties: {
              key: { type: :string },
              value: { nullable: true, description: 'New value, typed as `ProjektPhaseSettingsUpdate` lists for the key' }
            },
            required: ['key']
          }
        },
        required: ['projekt_phase_setting']
      }

      response '200', 'projekt phase setting updated' do
        let(:projekt) { Projekt.create!(name: 'Projekt For Phase Setting Update') }
        let(:phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::DebatePhase', active: true) }
        let(:id) { phase.id }
        let(:projekt_phase_setting) do
          { projekt_phase_setting: { key: 'feature.general.only_admins_create_debates', value: true } }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     projekt_phase_setting: { '$ref' => '#/components/schemas/ProjektPhaseSetting' }
                   },
                   required: ['projekt_phase_setting']
                 }
               },
               required: ['data']

        run_test! do
          stored_setting = phase.settings.find_by(key: 'feature.general.only_admins_create_debates')

          expect(stored_setting.value).to eq('active')
          expect(stored_setting.audits.last.comment).to eq("api_client:#{api_client.id}")
        end
      end

      response '404', 'setting key the phase type does not have' do
        let(:projekt) { Projekt.create!(name: 'Projekt For Phase Setting Update') }
        let(:phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::CommentPhase', active: true) }
        let(:id) { phase.id }
        let(:projekt_phase_setting) do
          { projekt_phase_setting: { key: 'feature.general.newest_first', value: true } }
        end

        run_test! do
          expect(phase.settings.find_by(key: 'feature.general.newest_first')).to be_nil
        end
      end

      response '422', 'invalid request' do
        let(:projekt) { Projekt.create!(name: 'Projekt For Phase Setting Update') }
        let(:phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::CommentPhase', active: true) }
        let(:id) { phase.id }
        let(:projekt_phase_setting) do
          { projekt_phase_setting: { value: 'active' } }
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

      response '422', 'value of the wrong type' do
        let(:projekt) { Projekt.create!(name: 'Projekt For Phase Setting Update') }
        let(:phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::ProposalPhase', active: true) }
        let(:id) { phase.id }
        let(:projekt_phase_setting) do
          { projekt_phase_setting: { key: 'option.form.description_max_length', value: 'long' } }
        end

        run_test! do
          expect(phase.settings.find_by(key: 'option.form.description_max_length').value).to eq('6000')
        end
      end

      unauthorized_response { let(:id) { 1 } }
      forbidden_response { let(:id) { existing_projekt_phase.id } }
    end
  end

  path '/api/projekt_phases/{id}/update_settings' do
    parameter name: :id, in: :path, type: :integer, description: 'Projekt Phase ID'

    patch 'Update multiple projekt phase settings' do
      tags 'Projekt Phases'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Bulk-update several settings of a projekt phase. Every key must be one the " \
                  "phase's type lists (`ProjektPhaseSettingsUpdate` shows all keys and their " \
                  "types); unknown keys are never created. All or nothing: when one key is " \
                  "rejected no setting is written, `updated` is empty and `errors` lists each " \
                  "problem per key. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      parameter name: :settings, in: :body, description: 'Object whose keys are projekt phase setting keys and whose values are the new setting values', schema: {
        type: :object,
        properties: {
          settings: { '$ref' => '#/components/schemas/ProjektPhaseSettingsUpdate' }
        },
        required: ['settings']
      }

      response '200', 'settings processed' do
        let(:projekt) { Projekt.create!(name: 'Projekt For Phase Settings Update') }
        let(:phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::ProposalPhase', active: true) }
        let(:id) { phase.id }
        let(:settings) do
          {
            settings: {
              'feature.form.show_map' => false,
              'option.form.description_max_length' => 3000,
              'selectable_setting.general.default_order' => 'created_at'
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     updated: { type: :array, items: { type: :string } },
                     errors: { type: :object }
                   },
                   required: %w[updated errors]
                 }
               },
               required: ['data']

        run_test! do |response|
          expect(JSON.parse(response.body)['data']['updated']).to match_array(settings[:settings].keys)
          expect(phase.settings.find_by(key: 'option.form.description_max_length').value).to eq('3000')
        end
      end

      response '200', 'unknown key - nothing is written or created' do
        let(:projekt) { Projekt.create!(name: 'Projekt For Phase Settings Update') }
        let(:phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::ProposalPhase', active: true) }
        let(:id) { phase.id }
        let(:settings) do
          { settings: { 'feature.form.show_map' => false, 'feature.general.newest_first' => 'active' } }
        end

        run_test! do |response|
          data = JSON.parse(response.body)['data']

          expect(data['updated']).to eq([])
          expect(data['errors'].keys).to eq(['feature.general.newest_first'])
          expect(phase.settings.find_by(key: 'feature.general.newest_first')).to be_nil
          expect(phase.settings.find_by(key: 'feature.form.show_map').value).to eq('active')
        end
      end

      response '422', 'settings parameter missing' do
        let(:projekt) { Projekt.create!(name: 'Projekt For Phase Settings Update') }
        let(:phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::CommentPhase', active: true) }
        let(:id) { phase.id }
        let(:settings) { {} }

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

      unauthorized_response { let(:id) { 1 } }
      forbidden_response { let(:id) { existing_projekt_phase.id } }
    end
  end

  path '/api/projekt_phases/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'Projekt Phase ID'

    get 'Retrieve a projekt phase' do
      tags 'Projekt Phases'
      produces 'application/json'
      security [bearer_auth: []]
      description "Retrieve a single projekt phase by ID with all its configuration details. Returns the phase type, active status, dates, visibility settings, restrictions (geozone, age range, user status), and all settings. The author_id of nested questions and pins is only returned to admin clients. #{ApiAccessRequirements::GET_READ_ONLY}"

      response '200', 'projekt phase found and returned' do
        let(:projekt) { Projekt.create!(name: 'Projekt For Phase Show') }
        let(:test_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::CommentPhase', active: true, phase_tab_name: 'Comments') }
        let(:id) { test_phase.id }

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     projekt_phase: { '$ref' => '#/components/schemas/ProjektPhase' }
                   },
                   required: ['projekt_phase']
                 }
               },
               required: ['data']

        run_test!
      end

      response '200', 'Mitmachbox survey id returned to admin clients only' do
        let(:projekt) { Projekt.create!(name: 'Projekt For Phase Show') }
        let(:test_phase) do
          projekt.projekt_phases.create!(type: 'ProjektPhase::MitmachboxPhase', active: true).tap do |mitmachbox_phase|
            mitmachbox_phase.update_column(:mitmachbox_survey_id, 'svy_8c1d')
          end
        end
        let(:id) { test_phase.id }

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     projekt_phase: { '$ref' => '#/components/schemas/ProjektPhase' }
                   },
                   required: ['projekt_phase']
                 }
               },
               required: ['data']

        run_test! do |response|
          expect(JSON.parse(response.body)['data']['projekt_phase']['mitmachbox_survey_id']).to eq('svy_8c1d')

          public_client = create_api_client(name: 'Public Client', access_level: :public_data)
          public_phase_data = ProjektPhaseSerializer.new(test_phase.reload, current_api_client: public_client).serialize

          expect(public_phase_data).not_to have_key(:mitmachbox_survey_id)
        end
      end

      response '404', 'projekt phase not found' do
        let(:id) { 999999 }

        run_test!
      end

      unauthorized_response { let(:id) { 1 } }
    end

    patch 'Update a projekt phase' do
      tags 'Projekt Phases'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Update an existing projekt phase configuration. All fields are optional - only provide fields to change. Supports updating dates, visibility, restrictions, texts per language (translations), settings, and more. The phase type cannot be changed. Returns the updated phase. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      parameter name: :projekt_phase, in: :body, description: 'Phase attributes to update - all optional (dates, active status, visibility, restrictions, texts per language, settings, etc.). The type of a phase cannot be changed.', schema: {
        type: :object,
        properties: {
          projekt_phase: { '$ref' => '#/components/schemas/ProjektPhaseRequestParams' }
        },
        required: ['projekt_phase']
      }

      request_body_example(
        name: 'texts_in_two_languages',
        summary: 'Write the tab name and button texts in German and English',
        value: {
          projekt_phase: {
            translations: {
              de: { phase_tab_name: 'Vorschläge', cta_button_name: 'Vorschlag einreichen' },
              en: { phase_tab_name: 'Proposals', cta_button_name: 'Submit a proposal' }
            }
          }
        }
      )

      response '200', 'projekt phase updated' do
        let(:projekt) { Projekt.create!(name: 'Projekt For Phase Update') }
        let(:test_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::CommentPhase', active: true, phase_tab_name: 'Comments') }
        let(:id) { test_phase.id }
        let(:projekt_phase) do
          {
            projekt_phase: {
              active: false,
              phase_tab_name: 'Updated Title'
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     projekt_phase: { '$ref' => '#/components/schemas/ProjektPhase' }
                   },
                   required: ['projekt_phase']
                 }
               },
               required: ['data']

        run_test!
      end

      response '200', 'texts written per language, restrictions set, type kept' do
        let(:projekt) { Projekt.create!(name: 'Projekt For Phase Update') }
        let(:test_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::CommentPhase', active: true, phase_tab_name: 'Comments') }
        let(:district) { RegisteredAddress::District.create!(name: 'Mitte') }
        let(:street) { RegisteredAddress::Street.create!(name: 'Hauptstraße', plz: '44787') }
        let(:id) { test_phase.id }
        let(:projekt_phase) do
          {
            projekt_phase: {
              type: 'ProjektPhase::ProposalPhase',
              geozone_restricted: 'only_streets',
              registered_address_district_ids: [district.id],
              registered_address_street_ids: [street.id],
              translations: {
                de: { phase_tab_name: 'Vorschläge', cta_button_name: 'Vorschlag einreichen' },
                en: { phase_tab_name: 'Proposals', cta_button_name: 'Submit a proposal' }
              }
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     projekt_phase: { '$ref' => '#/components/schemas/ProjektPhase' }
                   },
                   required: ['projekt_phase']
                 }
               },
               required: ['data']

        run_test! do |response|
          phase_data = JSON.parse(response.body)['data']['projekt_phase']

          expect(phase_data['type']).to eq('ProjektPhase::CommentPhase')
          expect(phase_data['translations']['de']).to include('phase_tab_name' => 'Vorschläge', 'cta_button_name' => 'Vorschlag einreichen')
          expect(phase_data['translations']['en']).to include('phase_tab_name' => 'Proposals', 'cta_button_name' => 'Submit a proposal')
          expect(phase_data['registered_address_district_ids']).to eq([district.id])
          expect(phase_data['registered_address_street_ids']).to eq([street.id])
          expect(test_phase.reload.type).to eq('ProjektPhase::CommentPhase')
        end
      end

      response '200', 'nested translations_attributes keep working' do
        let(:projekt) { Projekt.create!(name: 'Projekt For Phase Update') }
        let(:test_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::CommentPhase', active: true, phase_tab_name: 'Comments') }
        let(:id) { test_phase.id }
        let(:other_locale) { (I18n.available_locales - [I18n.locale]).first }
        let(:projekt_phase) do
          {
            projekt_phase: {
              translations_attributes: [{ locale: other_locale, phase_tab_name: 'Discussion', description: 'Talk about it' }]
            }
          }
        end

        run_test! do
          added_translation = test_phase.reload.translations.find { |translation| translation.locale == other_locale }

          expect(added_translation.phase_tab_name).to eq('Discussion')
          expect(added_translation.description).to eq('Talk about it')
        end
      end

      response '422', 'language the instance does not offer' do
        let(:projekt) { Projekt.create!(name: 'Projekt For Phase Update') }
        let(:test_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::CommentPhase', active: true, phase_tab_name: 'Comments') }
        let(:id) { test_phase.id }
        let(:projekt_phase) { { projekt_phase: { translations: { xx: { phase_tab_name: 'Unknown' } } } } }

        run_test! do |response|
          expect(JSON.parse(response.body)['error']['details']['translations']).to eq(['contain unsupported languages: xx'])
        end
      end

      response '422', 'invalid request' do
        let(:projekt) { Projekt.create!(name: 'Projekt For Phase Update') }
        let(:test_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::CommentPhase', active: true, phase_tab_name: 'Comments') }
        let(:id) { test_phase.id }
        let(:projekt_phase) do
          {
            projekt_phase: {
              start_date: '2030-01-01',
              end_date: '2020-01-01'
            }
          }
        end

        before do
          allow_any_instance_of(ProjektPhase).to receive(:save).and_return(false)
          errors_mock = double('errors').as_null_object
          allow(errors_mock).to receive(:full_messages).and_return(['End date must be after start date'])
          allow_any_instance_of(ProjektPhase).to receive(:errors).and_return(errors_mock)
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

      unauthorized_response { let(:id) { 1 } }
      forbidden_response { let(:id) { existing_projekt_phase.id } }
    end

    delete 'Delete a projekt phase' do
      tags 'Projekt Phases'
      produces 'application/json'
      security [bearer_auth: []]
      description "Delete a projekt phase and all associated data. This action is permanent and cannot be undone. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      response '200', 'projekt phase deleted' do
        let(:projekt) { Projekt.create!(name: 'Projekt For Phase Delete') }
        let(:test_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::CommentPhase', active: true) }
        let(:id) { test_phase.id }

        schema type: :object,
               properties: {
                 message: { type: :string }
               },
               required: ['message']

        run_test!
      end

      response '404', 'projekt phase not found' do
        let(:id) { 999999 }

        run_test!
      end

      response '422', 'unable to delete projekt phase' do
        let(:projekt) { Projekt.create!(name: 'Projekt For Phase Delete') }
        let(:test_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::CommentPhase', active: true) }
        let(:id) { test_phase.id }

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
          allow_any_instance_of(ProjektPhase).to receive(:destroy).and_return(false)
          errors_mock = double('errors').as_null_object
          allow(errors_mock).to receive(:messages).and_return({ base: ['Cannot delete projekt phase'] })
          allow_any_instance_of(ProjektPhase).to receive(:errors).and_return(errors_mock)
        end

        run_test!
      end

      unauthorized_response { let(:id) { 1 } }
      forbidden_response { let(:id) { existing_projekt_phase.id } }
    end
  end
end


