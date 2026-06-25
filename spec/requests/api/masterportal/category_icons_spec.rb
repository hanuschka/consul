# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Masterportal Category Icons API', type: :request, openapi_spec: 'v1/swagger.yaml' do
  let(:sync_token) { 'test-masterportal-sync-token' }
  let(:Authorization) { "Bearer #{sync_token}" }

  before do
    allow(Rails.application.secrets)
      .to receive(:masterportal_sync_api_token)
      .and_return(sync_token)
  end

  path '/api/masterportal/category_icons' do
    post 'Sync a category icon from Masterportal' do
      tags 'Masterportal'
      consumes 'multipart/form-data'
      produces 'application/json'
      security [masterportal_sync_auth: []]
      description "Upload and attach an icon image to a ProjektPointOfInterestCategory identified by projekt_phase_id + category_name. Used by external Masterportal systems to sync POI category icons.\n\n*Authentication: This endpoint uses the static Masterportal sync secret sent as `Authorization: Bearer <token>`, NOT an ApiClient access token. The `admin` / `public_data` access-level model does not apply.*"

      parameter name: :projekt_phase_id, in: :formData, type: :integer, required: true,
                description: 'Projekt Phase ID (PointOfInterestPhase)'
      parameter name: :category_name, in: :formData, type: :string, required: true,
                description: 'Category name (case-insensitive match)'
      parameter name: :icon, in: :formData, type: :file, required: true,
                description: 'Icon image (image/svg+xml, image/png, image/jpeg, max 512KB)'

      response '204', 'icon attached' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:poi_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::PointOfInterestPhase', active: true) }
        let!(:category) do
          poi_phase.projekt_point_of_interest_categories.create!(
            name: 'Barrierefrei',
            color: '#FF0000',
            icon: 'map-pin'
          )
        end
        let(:projekt_phase_id) { poi_phase.id }
        let(:category_name) { 'barrierefrei' }
        let(:icon) do
          Rack::Test::UploadedFile.new(
            Rails.root.join('spec/fixtures/files/1x1.png'),
            'image/png'
          )
        end

        run_test! do
          expect(category.reload.icon_image).to be_attached
        end
      end

      response '401', 'invalid or missing sync token' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:poi_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::PointOfInterestPhase', active: true) }
        let!(:category) do
          poi_phase.projekt_point_of_interest_categories.create!(
            name: 'Barrierefrei',
            color: '#FF0000',
            icon: 'map-pin'
          )
        end
        let(:projekt_phase_id) { poi_phase.id }
        let(:category_name) { 'barrierefrei' }
        let(:icon) do
          Rack::Test::UploadedFile.new(
            Rails.root.join('spec/fixtures/files/1x1.png'),
            'image/png'
          )
        end
        let(:Authorization) { 'Bearer wrong-token' }

        run_test!
      end

      response '404', 'no matching category' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:poi_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::PointOfInterestPhase', active: true) }
        let(:projekt_phase_id) { poi_phase.id }
        let(:category_name) { 'does-not-exist' }
        let(:icon) do
          Rack::Test::UploadedFile.new(
            Rails.root.join('spec/fixtures/files/1x1.png'),
            'image/png'
          )
        end

        run_test!
      end

      response '422', 'invalid content type' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:poi_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::PointOfInterestPhase', active: true) }
        let!(:category) do
          poi_phase.projekt_point_of_interest_categories.create!(
            name: 'Barrierefrei',
            color: '#FF0000',
            icon: 'map-pin'
          )
        end
        let(:projekt_phase_id) { poi_phase.id }
        let(:category_name) { 'barrierefrei' }
        let(:icon) do
          Rack::Test::UploadedFile.new(
            Rails.root.join('spec/fixtures/files/clippy.pdf'),
            'application/pdf'
          )
        end

        schema type: :object,
               properties: {
                 error: { type: :string }
               }

        run_test!
      end

      response '422', 'oversize upload' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:poi_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::PointOfInterestPhase', active: true) }
        let!(:category) do
          poi_phase.projekt_point_of_interest_categories.create!(
            name: 'Barrierefrei',
            color: '#FF0000',
            icon: 'map-pin'
          )
        end
        let(:projekt_phase_id) { poi_phase.id }
        let(:category_name) { 'barrierefrei' }
        let(:icon) do
          Rack::Test::UploadedFile.new(
            StringIO.new('A' * (513 * 1024)),
            'image/png',
            original_filename: 'big.png'
          )
        end

        schema type: :object,
               properties: {
                 error: { type: :string }
               }

        run_test!
      end
    end
  end
end
