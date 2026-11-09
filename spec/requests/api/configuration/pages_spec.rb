# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Configuration Pages API', type: :request, openapi_spec: 'v1/swagger.yaml' do
  let!(:api_client) { create_configuration_api_client }
  let(:Authorization) { "Bearer #{api_client.access_token}" }

  # Seeds create every footer page; a test page starts as a draft.
  def footer_page(footer_key)
    SiteCustomization::Page.footer_pages.find_by!(footer_key: footer_key).tap do |page|
      page.update_column(:status, "draft")
    end
  end

  def create_landing_page(attributes = {})
    Globalize.with_locale(:de) do
      default_attributes = {
        slug: "landing-#{SecureRandom.hex(3)}", landing: true, status: 'draft', title: 'Mobilität'
      }

      SiteCustomization::Page.create!(default_attributes.merge(attributes))
    end
  end

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

  footer_translation_properties = {
    title: { type: :string, example: 'Impressum' },
    subtitle: { type: :string, nullable: true },
    content: { type: :string, nullable: true, description: 'HTML; cleaned like the /adm editor output' }
  }

  landing_translation_properties = {
    title: { type: :string, example: 'Mobilität in unserer Stadt' },
    subtitle: { type: :string, nullable: true },
    header_title: { type: :string, nullable: true },
    content: { type: :string, nullable: true, description: 'HTML; cleaned like the /adm editor output' }
  }

  translations_response_schema = lambda do |translation_properties|
    {
      type: :object,
      description: 'Texts per language, keyed by locale',
      additionalProperties: { type: :object, properties: translation_properties }
    }
  end

  footer_page_schema = {
    type: :object,
    properties: {
      id: { type: :integer, example: 3 },
      footer_key: { type: :string, enum: SiteCustomization::Page::FOOTER_KEYS },
      slug: { type: :string, example: 'impressum' },
      url: { type: :string, example: '/impressum' },
      status: { type: :string, enum: SiteCustomization::Page::VALID_STATUSES },
      footer_position: { type: :integer, nullable: true },
      published_at: { type: :string, format: :date_time, nullable: true },
      translations: translations_response_schema.call(footer_translation_properties),
      updated_at: { type: :string, format: :date_time }
    },
    required: %w[id footer_key slug status translations]
  }

  landing_page_schema = {
    type: :object,
    properties: {
      id: { type: :integer, example: 12 },
      slug: { type: :string, example: 'mobilitaet' },
      url: { type: :string, example: '/mobilitaet' },
      status: { type: :string, enum: SiteCustomization::Page::VALID_STATUSES },
      published_at: { type: :string, format: :date_time, nullable: true },
      landing_nav_position: { type: :integer, nullable: true },
      landing_show_in_top_nav: { type: :boolean },
      landing_hide_title_and_subtitle: { type: :boolean },
      landing_site_logo_follow_to_landing_page: { type: :boolean },
      landing_navigation_link_color: { type: :string, example: '#000000' },
      brand_color: { type: :string, nullable: true, example: '#004a83' },
      projekt_id: { type: :integer, nullable: true },
      translations: translations_response_schema.call(landing_translation_properties),
      attachments: {
        type: :object,
        properties: Api::Configuration::LandingPagesController::ATTACHMENTS.keys.index_with { attachment_schema }
      },
      created_at: { type: :string, format: :date_time },
      updated_at: { type: :string, format: :date_time }
    },
    required: %w[id slug status translations attachments]
  }

  translations_request_schema = lambda do |translation_properties|
    {
      type: :object,
      description: Schemas::Configuration::TRANSLATIONS_DESCRIPTION,
      properties: I18n.available_locales.to_h do |locale|
        [locale.to_s, { type: :object, properties: translation_properties }]
      end
    }
  end

  landing_page_request_schema = {
    type: :object,
    properties: {
      landing_page: {
        type: :object,
        properties: {
          slug: { type: :string, pattern: '^[0-9a-zA-Z\-_]*$', example: 'mobilitaet' },
          status: { type: :string, enum: SiteCustomization::Page::VALID_STATUSES },
          landing_show_in_top_nav: { type: :boolean },
          landing_hide_title_and_subtitle: { type: :boolean },
          landing_site_logo_follow_to_landing_page: { type: :boolean },
          landing_navigation_link_color: {
            type: :string, nullable: true, pattern: TypedValueParser::COLOR_FORMAT.source,
            description: 'Hex colour; empty resets it to #000000'
          },
          brand_color: { type: :string, nullable: true, pattern: TypedValueParser::COLOR_FORMAT.source },
          translations: translations_request_schema.call(landing_translation_properties),
          attachments: {
            type: :object,
            description: 'Files to upload, base64 encoded (bare or data URI), keyed by attachment. ' \
                         'Videos: MP4/WebM up to 50 MB. Images and logos: PNG or JPEG.',
            additionalProperties: false,
            properties: Api::Configuration::LandingPagesController::ATTACHMENTS.keys.index_with { { type: :string } }
          },
          remove_attachments: {
            type: :array,
            items: { type: :string, enum: Api::Configuration::LandingPagesController::ATTACHMENTS.keys },
            description: 'Attachments to remove'
          }
        }
      }
    },
    required: ['landing_page']
  }

  path '/api/configuration/footer_pages' do
    get 'List footer pages' do
      tags 'Configuration Pages'
      produces 'application/json'
      security [bearer_auth: []]
      description "The pages linked from the public footer (imprint, privacy, terms, accessibility …) " \
                  "in footer order.#{ApiAccessRequirements::CONFIGURATION_REQUIRED}"

      response '200', 'footer pages listed' do
        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: { footer_pages: { type: :array, items: footer_page_schema } },
                   required: ['footer_pages']
                 }
               }

        run_test! do |response|
          footer_keys = JSON.parse(response.body)['data']['footer_pages'].map { |page| page['footer_key'] }

          expect(footer_keys).to eq(SiteCustomization::Page.footer_pages.pluck(:footer_key))
        end
      end

      unauthorized_response
      configuration_forbidden_response
    end
  end

  path '/api/configuration/footer_pages/{id}' do
    parameter name: :id, in: :path, type: :integer, required: true

    get 'Show a footer page' do
      tags 'Configuration Pages'
      produces 'application/json'
      security [bearer_auth: []]
      description "One footer page with its texts per language.#{ApiAccessRequirements::CONFIGURATION_REQUIRED}"

      response '200', 'footer page found' do
        let(:id) { footer_page('impressum').id }

        schema type: :object, properties: { data: { type: :object, properties: { footer_page: footer_page_schema } } }

        run_test!
      end

      response '404', 'not a footer page' do
        let(:id) { create_landing_page.id }

        run_test!
      end

      unauthorized_response { let(:id) { 0 } }
      configuration_forbidden_response { let(:id) { footer_page('impressum').id } }
    end

    patch 'Change a footer page' do
      tags 'Configuration Pages'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Changes the status, position, slug and texts of a footer page. Content HTML is " \
                  "cleaned the way the /adm editor output is: scripts and unknown tags are removed." \
                  "#{ApiAccessRequirements::CONFIGURATION_REQUIRED}"
      parameter name: :body, in: :body, required: true, schema: {
        type: :object,
        properties: {
          footer_page: {
            type: :object,
            properties: {
              slug: { type: :string, pattern: '^[0-9a-zA-Z\-_]*$' },
              status: { type: :string, enum: SiteCustomization::Page::VALID_STATUSES },
              footer_position: { type: :integer, minimum: 1 },
              translations: translations_request_schema.call(footer_translation_properties)
            }
          }
        },
        required: ['footer_page']
      }

      response '200', 'footer page changed in two languages' do
        let(:impressum_page) { footer_page('impressum') }
        let(:id) { impressum_page.id }
        let(:body) do
          {
            footer_page: {
              status: 'published',
              translations: {
                de: { title: 'Impressum', content: '<p>Stadt Musterstadt</p><script>alert(1)</script>' },
                en: { title: 'Legal notice', content: '<p>City of Musterstadt</p>' }
              }
            }
          }
        end

        schema type: :object, properties: { data: { type: :object, properties: { footer_page: footer_page_schema } } }

        run_test! do |response|
          translations = JSON.parse(response.body)['data']['footer_page']['translations']
          german_content = impressum_page.reload.translations.find_by(locale: 'de').content

          expect(impressum_page.status).to eq('published')
          expect(translations['en']['title']).to eq('Legal notice')
          expect(german_content).to include('Stadt Musterstadt')
          expect(german_content).not_to include('<script')

          audit = impressum_page.audits.last
          expect(audit.audited_changes['status']).to eq(%w[draft published])
          expect(audit.user).to eq(api_client.content_author)
          expect(audit.comment).to eq("api_client:#{api_client.id}")
          expect(impressum_page.associated_audits.where(comment: "api_client:#{api_client.id}")).to exist
        end
      end

      response '422', 'invalid status and unsupported language' do
        let(:id) { footer_page('impressum').id }
        let(:body) do
          { footer_page: { status: 'archived', translations: { tlh: { title: 'Klingonisch' } } } }
        end

        schema '$ref' => '#/components/schemas/ConfigurationValidationError'

        run_test! do |response|
          details = JSON.parse(response.body)['error']['details']

          expect(details.keys).to match_array(%w[status translations])
        end
      end

      response '404', 'footer page not found' do
        let(:id) { 0 }
        let(:body) { { footer_page: { status: 'published' } } }

        run_test!
      end

      unauthorized_response { let(:id) { 0 } }
      configuration_forbidden_response { let(:id) { footer_page('impressum').id } }
    end
  end

  path '/api/configuration/landing_pages' do
    get 'List landing pages' do
      tags 'Configuration Pages'
      produces 'application/json'
      security [bearer_auth: []]
      description "Landing pages in navigation order, with their texts, colours, header images, " \
                  "videos and logos.#{ApiAccessRequirements::CONFIGURATION_REQUIRED}"
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Pagination page number'
      parameter name: :per_page, in: :query, type: :integer, required: false, description: 'Items per page'

      response '200', 'landing pages listed' do
        before do
          create_landing_page(landing_nav_position: 2, title: 'Klima')
          create_landing_page(landing_nav_position: 1, title: 'Mobilität')
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: { landing_pages: { type: :array, items: landing_page_schema } },
                   required: ['landing_pages']
                 },
                 pagination: Schemas::Miscellaneous::PAGINATION_RESPONSE_SCHEMA
               }

        run_test! do |response|
          titles = JSON.parse(response.body)['data']['landing_pages'].map do |landing_page|
            landing_page['translations']['de']['title']
          end

          expect(titles).to eq(%w[Mobilität Klima])
        end
      end

      unauthorized_response
      configuration_forbidden_response
    end

    post 'Create a landing page' do
      tags 'Configuration Pages'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Creates a landing page; it starts as a draft unless `status` says otherwise. " \
                  "A title is required in at least one language.#{ApiAccessRequirements::CONFIGURATION_REQUIRED}"
      parameter name: :body, in: :body, required: true, schema: landing_page_request_schema

      response '201', 'landing page created with a logo' do
        let(:body) do
          {
            landing_page: {
              slug: 'mobilitaet',
              brand_color: '#004A83',
              landing_show_in_top_nav: true,
              translations: { de: { title: 'Mobilität', content: '<h2>Unterwegs</h2>' } },
              attachments: {
                landing_site_logo_for_white_background: base64_fixture('logo_header.png', 'image/png')
              }
            }
          }
        end

        schema type: :object, properties: { data: { type: :object, properties: { landing_page: landing_page_schema } } }

        run_test! do |response|
          landing_page_data = JSON.parse(response.body)['data']['landing_page']
          landing_page = SiteCustomization::Page.find(landing_page_data['id'])
          logo_audit = Audit.where(auditable: landing_page)
                            .detect { |audit| audit.audited_changes.key?('landing_site_logo_for_white_background') }

          expect(landing_page).to be_landing
          expect(landing_page.status).to eq('draft')
          expect(landing_page.brand_color).to eq('#004a83')
          expect(landing_page.landing_site_logo_for_white_background).to be_attached
          expect(landing_page_data['attachments']['landing_site_logo_for_white_background']['content_type'])
            .to eq('image/png')
          expect(landing_page.audits.find_by(action: 'create').comment).to eq("api_client:#{api_client.id}")
          expect(logo_audit.user).to eq(api_client.content_author)
        end
      end

      response '422', 'invalid colour, unknown attachment and missing title' do
        let(:body) do
          {
            landing_page: {
              slug: 'klima',
              brand_color: 'blue',
              attachments: { background: base64_fixture('clippy.png', 'image/png') }
            }
          }
        end

        schema '$ref' => '#/components/schemas/ConfigurationValidationError'

        run_test! do |response|
          details = JSON.parse(response.body)['error']['details']

          expect(details.keys).to match_array(%w[brand_color attachments.background])
          expect(SiteCustomization::Page.landing.where(slug: 'klima')).not_to exist
        end
      end

      response '422', 'landing page without a title' do
        let(:body) { { landing_page: { slug: 'ohne-titel' } } }

        schema '$ref' => '#/components/schemas/ConfigurationValidationError'

        run_test!
      end

      unauthorized_response
      configuration_forbidden_response
    end
  end

  path '/api/configuration/landing_pages/{id}' do
    parameter name: :id, in: :path, type: :integer, required: true

    get 'Show a landing page' do
      tags 'Configuration Pages'
      produces 'application/json'
      security [bearer_auth: []]
      description "One landing page.#{ApiAccessRequirements::CONFIGURATION_REQUIRED}"

      response '200', 'landing page found' do
        let(:id) { create_landing_page.id }

        schema type: :object, properties: { data: { type: :object, properties: { landing_page: landing_page_schema } } }

        run_test!
      end

      response '404', 'not a landing page' do
        let(:id) { footer_page('impressum').id }

        run_test!
      end

      unauthorized_response { let(:id) { 0 } }
      configuration_forbidden_response { let(:id) { create_landing_page.id } }
    end

    patch 'Change a landing page' do
      tags 'Configuration Pages'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Changes a landing page. Attachments listed in `attachments` are replaced, those " \
                  "in `remove_attachments` removed; others stay as they are." \
                  "#{ApiAccessRequirements::CONFIGURATION_REQUIRED}"
      parameter name: :body, in: :body, required: true, schema: landing_page_request_schema

      response '200', 'landing page changed and its logo removed' do
        let(:landing_page) do
          create_landing_page.tap do |page|
            page.landing_site_logo_for_white_background.attach(
              io: file_fixture('logo_header.png').open, filename: 'logo_header.png'
            )
          end
        end
        let(:id) { landing_page.id }
        let(:body) do
          {
            landing_page: {
              status: 'published',
              landing_navigation_link_color: '',
              translations: { de: { subtitle: 'Gemeinsam unterwegs' } },
              remove_attachments: ['landing_site_logo_for_white_background']
            }
          }
        end

        schema type: :object, properties: { data: { type: :object, properties: { landing_page: landing_page_schema } } }

        run_test! do
          landing_page.reload
          removal_audit = Audit.where(auditable: landing_page)
                               .detect { |audit| audit.audited_changes.key?('landing_site_logo_for_white_background') }

          expect(landing_page.status).to eq('published')
          expect(landing_page.landing_navigation_link_color).to eq('#000000')
          expect(landing_page.subtitle).to eq('Gemeinsam unterwegs')
          expect(landing_page.landing_site_logo_for_white_background).not_to be_attached
          expect(removal_audit.audited_changes['landing_site_logo_for_white_background'].last).to be_nil
        end
      end

      response '422', 'video slot given an image' do
        let(:id) { create_landing_page.id }
        let(:body) do
          { landing_page: { attachments: { landing_desktop_header_video: base64_fixture('clippy.png', 'image/png') } } }
        end

        schema '$ref' => '#/components/schemas/ConfigurationValidationError'

        run_test! do
          expect(SiteCustomization::Page.find(id).landing_desktop_header_video).not_to be_attached
        end
      end

      response '422', 'image slot given a file that is not an image, whatever type it claims' do
        let(:id) { create_landing_page.id }
        let(:body) do
          svg_file = Base64.strict_encode64('<svg xmlns="http://www.w3.org/2000/svg"><script>alert(1)</script></svg>')

          { landing_page: { attachments: { landing_desktop_header_image: "data:image/png;base64,#{svg_file}" } } }
        end

        schema '$ref' => '#/components/schemas/ConfigurationValidationError'

        run_test! do |response|
          expect(JSON.parse(response.body)['error']['details'].keys).to eq(['attachments.landing_desktop_header_image'])
          expect(SiteCustomization::Page.find(id).landing_desktop_header_image).not_to be_attached
        end
      end

      response '404', 'landing page not found' do
        let(:id) { 0 }
        let(:body) { { landing_page: { status: 'published' } } }

        run_test!
      end

      unauthorized_response { let(:id) { 0 } }
      configuration_forbidden_response { let(:id) { create_landing_page.id } }
    end

    delete 'Delete a landing page' do
      tags 'Configuration Pages'
      produces 'application/json'
      security [bearer_auth: []]
      description "Deletes a landing page. A landing page that belongs to a projekt cannot be " \
                  "deleted.#{ApiAccessRequirements::CONFIGURATION_REQUIRED}"

      response '200', 'landing page deleted' do
        let(:id) { create_landing_page.id }

        run_test! do
          expect(SiteCustomization::Page.where(id: id)).not_to exist
          expect(Audit.where(auditable_type: 'SiteCustomization::Page', auditable_id: id, action: 'destroy'))
            .to exist
        end
      end

      response '422', 'landing page belongs to a projekt' do
        let(:id) { create_landing_page(projekt: create(:projekt)).id }

        schema '$ref' => '#/components/schemas/ConfigurationValidationError'

        run_test!
      end

      response '404', 'landing page not found' do
        let(:id) { 0 }

        run_test!
      end

      unauthorized_response { let(:id) { 0 } }
      configuration_forbidden_response { let(:id) { create_landing_page.id } }
    end
  end
end
