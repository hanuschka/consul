# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Configuration Media API', type: :request, openapi_spec: 'v1/swagger.yaml' do
  let!(:api_client) { create_configuration_api_client }
  let(:Authorization) { "Bearer #{api_client.access_token}" }

  def base64_fixture(filename, content_type)
    "data:#{content_type};base64,#{Base64.strict_encode64(file_fixture(filename).binread)}"
  end

  attachment_schema = {
    type: :object,
    nullable: true,
    properties: {
      url: { type: :string, format: :uri },
      filename: { type: :string },
      content_type: { type: :string },
      byte_size: { type: :integer }
    }
  }

  image_slot_schema = {
    type: :object,
    properties: {
      name: { type: :string, enum: SiteCustomization::Image::VALID_IMAGES.keys },
      required_width: { type: :integer, nullable: true },
      required_height: { type: :integer, nullable: true },
      size_rule: {
        type: :string,
        enum: %w[exact minimum any],
        description: '`exact`: must match the required size; `minimum`: at least that size; `any`: no size check'
      },
      image: attachment_schema
    },
    required: %w[name size_rule]
  }

  video_slot_schema = {
    type: :object,
    properties: {
      name: { type: :string, enum: SiteCustomization::Video::VALID_VIDEOS },
      allowed_content_types: { type: :array, items: { type: :string } },
      max_byte_size: { type: :integer },
      video: attachment_schema
    },
    required: %w[name]
  }

  path '/api/configuration/images' do
    get 'List image slots' do
      tags 'Configuration Media'
      produces 'application/json'
      security [bearer_auth: []]
      description "All logo and image slots of the instance (header logos, email logos, social " \
                  "media images, touch icon, favicon, header images, map image) with their size " \
                  "rules and current file.#{ApiAccessRequirements::CONFIGURATION_REQUIRED}"

      response '200', 'image slots listed' do
        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: { images: { type: :array, items: image_slot_schema } },
                   required: ['images']
                 }
               }

        run_test! do |response|
          names = JSON.parse(response.body)['data']['images'].map { |image| image['name'] }

          expect(names).to eq(SiteCustomization::Image::VALID_IMAGES.keys)
          expect(names).to include('favicon')
        end
      end

      unauthorized_response
      configuration_forbidden_response
    end
  end

  path '/api/configuration/images/{name}' do
    parameter name: :name, in: :path, required: true,
              schema: { type: :string, enum: SiteCustomization::Image::VALID_IMAGES.keys }

    put 'Upload an image into a slot' do
      tags 'Configuration Media'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Replaces the slot's image. Send the file base64 encoded, bare or as a data URI. " \
                  "PNG or JPEG; logos up to 2 MB; the size rule of the slot applies." \
                  "#{ApiAccessRequirements::CONFIGURATION_REQUIRED}"
      parameter name: :body, in: :body, required: true, schema: {
        type: :object,
        properties: {
          image: {
            type: :object,
            properties: { attachment: { type: :string, description: 'Base64 file or data URI' } },
            required: ['attachment']
          }
        },
        required: ['image']
      }

      response '200', 'logo uploaded' do
        let(:name) { 'logo_header' }
        let(:body) { { image: { attachment: base64_fixture('logo_header.png', 'image/png') } } }

        schema type: :object, properties: { data: { type: :object, properties: { image: image_slot_schema } } }

        run_test! do |response|
          image = JSON.parse(response.body)['data']['image']['image']
          image_slot = SiteCustomization::Image.find_by(name: 'logo_header')
          audit = Audit.where(auditable: image_slot).last

          expect(image['content_type']).to eq('image/png')
          expect(image_slot.persisted_image).to be_present
          expect(audit.audited_changes['image'].first).to be_nil
          expect(audit.audited_changes['image'].last).to start_with('logo_header')
          expect(audit.comment).to eq("api_client:#{api_client.id}")
        end
      end

      response '200', 'favicon uploaded' do
        let(:name) { 'favicon' }
        let(:body) { { image: { attachment: base64_fixture('clippy.png', 'image/png') } } }

        run_test!
      end

      response '422', 'image does not meet the size rule of the slot' do
        let(:name) { 'apple-touch-icon-200' }
        let(:body) { { image: { attachment: base64_fixture('clippy.png', 'image/png') } } }

        schema '$ref' => '#/components/schemas/ConfigurationValidationError'

        run_test! do
          expect(SiteCustomization::Image.find_by(name: 'apple-touch-icon-200').persisted_image).to be_nil
        end
      end

      response '404', 'unknown slot' do
        let(:name) { 'background' }
        let(:body) { { image: { attachment: base64_fixture('clippy.png', 'image/png') } } }

        run_test!
      end

      unauthorized_response { let(:name) { 'logo_header' } }
      configuration_forbidden_response { let(:name) { 'logo_header' } }
    end

    delete 'Remove the image of a slot' do
      tags 'Configuration Media'
      produces 'application/json'
      security [bearer_auth: []]
      description "Removes the uploaded file; the platform falls back to its default image." \
                  "#{ApiAccessRequirements::CONFIGURATION_REQUIRED}"

      response '200', 'image removed' do
        let(:name) { 'logo_header' }

        before do
          image_slot = SiteCustomization::Image.find_or_create_by!(name: 'logo_header')
          image_slot.image.attach(io: file_fixture('logo_header.png').open, filename: 'logo_header.png')
        end

        run_test! do
          image_slot = SiteCustomization::Image.find_by(name: 'logo_header')

          expect(image_slot.reload.persisted_image).to be_nil
          expect(Audit.where(auditable: image_slot).last.audited_changes['image'].last).to be_nil
        end
      end

      unauthorized_response { let(:name) { 'logo_header' } }
      configuration_forbidden_response { let(:name) { 'logo_header' } }
    end
  end

  path '/api/configuration/videos' do
    get 'List video slots' do
      tags 'Configuration Media'
      produces 'application/json'
      security [bearer_auth: []]
      description "The header video slots (desktop and mobile).#{ApiAccessRequirements::CONFIGURATION_REQUIRED}"

      response '200', 'video slots listed' do
        schema type: :object,
               properties: {
                 data: { type: :object, properties: { videos: { type: :array, items: video_slot_schema } } }
               }

        run_test! do |response|
          names = JSON.parse(response.body)['data']['videos'].map { |video| video['name'] }

          expect(names).to eq(SiteCustomization::Video::VALID_VIDEOS)
        end
      end

      unauthorized_response
      configuration_forbidden_response
    end
  end

  path '/api/configuration/videos/{name}' do
    parameter name: :name, in: :path, required: true,
              schema: { type: :string, enum: SiteCustomization::Video::VALID_VIDEOS }

    put 'Upload a video into a slot' do
      tags 'Configuration Media'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Replaces the slot's video. MP4 or WebM, up to 50 MB, base64 encoded." \
                  "#{ApiAccessRequirements::CONFIGURATION_REQUIRED}"
      parameter name: :body, in: :body, required: true, schema: {
        type: :object,
        properties: {
          video: {
            type: :object,
            properties: { attachment: { type: :string, description: 'Base64 file or data URI' } },
            required: ['attachment']
          }
        },
        required: ['video']
      }

      response '422', 'file is not a video' do
        let(:name) { 'header_video' }
        let(:body) { { video: { attachment: base64_fixture('clippy.png', 'image/png') } } }

        schema '$ref' => '#/components/schemas/ConfigurationValidationError'

        run_test!
      end

      response '400', 'attachment missing' do
        let(:name) { 'header_video' }
        let(:body) { { video: { attachment: '' } } }

        run_test!
      end

      unauthorized_response { let(:name) { 'header_video' } }
      configuration_forbidden_response { let(:name) { 'header_video' } }
    end

    delete 'Remove the video of a slot' do
      tags 'Configuration Media'
      produces 'application/json'
      security [bearer_auth: []]
      description "Removes the uploaded video.#{ApiAccessRequirements::CONFIGURATION_REQUIRED}"

      response '200', 'video slot without a file stays empty' do
        let(:name) { 'mobile_header_video' }

        run_test! do |response|
          expect(JSON.parse(response.body)['data']['video']['video']).to be_nil
        end
      end

      unauthorized_response { let(:name) { 'header_video' } }
      configuration_forbidden_response { let(:name) { 'header_video' } }
    end
  end
end
