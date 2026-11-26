# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Configuration Navigation API', type: :request, openapi_spec: 'v1/swagger.yaml' do
  let!(:api_client) { create_configuration_api_client }
  let(:Authorization) { "Bearer #{api_client.access_token}" }

  def create_landing_page
    SiteCustomization::Page.create!(
      slug: "landing-#{SecureRandom.hex(3)}", title: 'Landing page', status: 'published', landing: true
    )
  end

  def create_banner
    Banner.create!(
      target_url: 'https://example.com',
      post_started_at: Date.current - 1,
      post_ended_at: Date.current + 7,
      title: 'Banner title',
      description: 'Banner description'
    )
  end

  def create_modal_notification
    ModalNotification.create!(
      active_from: Date.current, active_to: Date.current + 7, title: 'Notice', html_content: '<p>Hi</p>'
    )
  end

  def expect_audited_by_client(record)
    audit = Audit.where(auditable: record).last

    expect(audit.comment).to eq("api_client:#{api_client.id}")
    expect(audit.user).to eq(api_client.content_author)
  end

  content_card_limits_description =
    SiteCustomization::ContentCard::DEFAULT_SETTINGS
      .map { |kind, settings| "#{kind}: #{settings.keys.join(", ").presence || "none"}" }
      .join("; ")
  
  data_schema = lambda do |name, record_schema|
    { type: :object, properties: { data: { type: :object, properties: { name => record_schema } } } }
  end

  navbar_item_schema = {
    type: :object,
    properties: {
      id: { type: :integer },
      kind: { type: :string, enum: NavbarItem.kinds.keys },
      preset: { type: :string, nullable: true, enum: NavbarItem::PRESETS.keys.map(&:to_s) + [nil] },
      projekt_id: { type: :integer, nullable: true },
      linked_page_id: { type: :integer, nullable: true },
      landing_page_id: {
        type: :integer, nullable: true, description: 'Set for items of a landing page menu'
      },
      parent_id: { type: :integer, nullable: true },
      position: { type: :integer },
      custom_title: { type: :string, nullable: true },
      title: { type: :string, nullable: true, description: 'Title shown in the menu' },
      external_url: { type: :string, nullable: true },
      open_in_new_tab: { type: :boolean },
      created_at: { type: :string, format: :date_time },
      updated_at: { type: :string, format: :date_time }
    },
    required: %w[id kind position open_in_new_tab]
  }

  navbar_item_input = {
    type: :object,
    properties: {
      kind: { type: :string, enum: NavbarItem.kinds.keys },
      preset: {
        type: :string,
        enum: NavbarItem::PRESETS.keys.map(&:to_s),
        description: "Required for `presets` items. Landing page menus allow only: " \
                     "#{NavbarItem::LANDING_PAGE_ALLOWED_PRESETS.join(", ")}"
      },
      projekt_id: { type: :integer, description: 'Required for `projekts` items' },
      linked_page_id: {
        type: :integer, description: 'Landing page to link; required for `landing_pages` items'
      },
      landing_page_id: {
        type: :integer, nullable: true, description: 'Put the item into a landing page menu'
      },
      parent_id: { type: :integer, nullable: true, description: 'Parent item in the same menu' },
      position: { type: :integer, minimum: 0 },
      custom_title: { type: :string, nullable: true, maxLength: 255 },
      external_url: { type: :string, format: :uri, description: 'Required for `external` items' },
      open_in_new_tab: { type: :boolean }
    }
  }

  content_block_schema = {
    type: :object,
    properties: {
      key: { type: :string, enum: Api::Configuration::ContentBlocksController::BLOCK_KEYS },
      body: { type: :string, nullable: true, description: 'Sanitized HTML' },
      visible: { type: :boolean },
      visible_from: { type: :string, format: :date_time, nullable: true },
      visible_until: { type: :string, format: :date_time, nullable: true },
      margin_bottom: { type: :integer },
      visibility_status: { type: :string, enum: %w[visible hidden scheduled expired] },
      body_stripped: {
        type: :boolean, description: 'Whether the sanitizer removed markup from the last write'
      },
      updated_at: { type: :string, format: :date_time, nullable: true }
    },
    required: %w[key visible margin_bottom visibility_status]
  }

  content_card_schema = {
    type: :object,
    properties: {
      id: { type: :integer },
      kind: { type: :string, enum: SiteCustomization::ContentCard::KINDS },
      landing_page_id: { type: :integer, nullable: true },
      active: { type: :boolean, nullable: true },
      position: { type: :integer, nullable: true },
      settings: { type: :object, additionalProperties: { type: :integer } },
      translations: Schemas::Configuration.translations_object(title: { type: :string }),
      updated_at: { type: :string, format: :date_time }
    },
    required: %w[id kind settings translations]
  }

  banner_schema = {
    type: :object,
    properties: {
      id: { type: :integer },
      target_url: { type: :string },
      post_started_at: { type: :string, format: :date },
      post_ended_at: { type: :string, format: :date },
      background_color: { type: :string },
      font_color: { type: :string },
      web_section_ids: { type: :array, items: { type: :integer } },
      active: { type: :boolean },
      translations: Schemas::Configuration.translations_object(
        title: { type: :string }, description: { type: :string }
      ),
      created_at: { type: :string, format: :date_time },
      updated_at: { type: :string, format: :date_time }
    },
    required: %w[id target_url post_started_at post_ended_at translations]
  }

  banner_input = {
    type: :object,
    properties: {
      target_url: { type: :string, description: 'Absolute http(s) URL or a path starting with /' },
      post_started_at: { type: :string, format: :date },
      post_ended_at: { type: :string, format: :date },
      background_color: { type: :string, pattern: TypedValueParser::COLOR_FORMAT.source, example: '#e7f2fc' },
      font_color: { type: :string, pattern: TypedValueParser::COLOR_FORMAT.source, example: '#222222' },
      web_section_ids: {
        type: :array,
        items: { type: :integer },
        description: "Ids of the web sections (homepage, debates, proposals, …) the banner shows on"
      },
      translations: Schemas::Configuration.translations_object(
        title: { type: :string, minLength: 2 },
        description: { type: :string }
      )
    }
  }

  modal_notification_schema = {
    type: :object,
    properties: {
      id: { type: :integer },
      active_from: { type: :string, format: :date },
      active_to: { type: :string, format: :date },
      current: { type: :boolean, description: 'Whether this is the notification shown today' },
      translations: Schemas::Configuration.translations_object(
        title: { type: :string }, html_content: { type: :string }
      ),
      created_at: { type: :string, format: :date_time },
      updated_at: { type: :string, format: :date_time }
    },
    required: %w[id translations]
  }

  modal_notification_input = {
    type: :object,
    properties: {
      active_from: { type: :string, format: :date },
      active_to: { type: :string, format: :date },
      translations: Schemas::Configuration.translations_object(
        title: { type: :string },
        html_content: { type: :string, description: 'HTML, sanitized before it is stored' }
      )
    }
  }

  path '/api/configuration/navbar_items' do
    get 'List navigation items' do
      tags 'Configuration Navigation'
      produces 'application/json'
      security [bearer_auth: []]
      description "Items of the main navigation, or of a landing page menu with `landing_page_id`." \
                  "#{ApiAccessRequirements::CONFIGURATION_REQUIRED}"
      parameter name: :landing_page_id, in: :query, type: :integer, required: false,
                description: 'List the menu of this landing page instead of the main navigation'
      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :per_page, in: :query, type: :integer, required: false

      response '200', 'navigation items listed' do
        before do
          NavbarItem.create!(kind: 'presets', preset: 'proposals', position: 1)
          NavbarItem.create!(kind: 'external', external_url: 'https://example.com', custom_title: 'Site')
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: { navbar_items: { type: :array, items: navbar_item_schema } }
                 },
                 pagination: Schemas::Miscellaneous::PAGINATION_RESPONSE_SCHEMA
               }

        run_test! do |response|
          expect(JSON.parse(response.body)['data']['navbar_items'].size).to eq(2)
        end
      end

      unauthorized_response
      configuration_forbidden_response
    end

    post 'Create a navigation item' do
      tags 'Configuration Navigation'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Adds an item. `kind` decides what it links to: a module overview (`presets`), " \
                  "a projekt, a landing page, or an external URL." \
                  "#{ApiAccessRequirements::CONFIGURATION_REQUIRED}"
      parameter name: :body, in: :body, required: true, schema: {
        type: :object,
        properties: { navbar_item: navbar_item_input },
        required: ['navbar_item']
      }

      response '201', 'navigation item created' do
        let(:body) do
          { navbar_item: { kind: 'presets', preset: 'polls', position: 2, open_in_new_tab: false } }
        end

        schema data_schema.call(:navbar_item, navbar_item_schema)

        run_test! do |response|
          navbar_item = NavbarItem.find(JSON.parse(response.body)['data']['navbar_item']['id'])

          expect(navbar_item.preset).to eq('polls')
          expect_audited_by_client(navbar_item)
        end
      end

      response '422', 'kind target missing or not allowed' do
        let(:landing_page) { create_landing_page }
        let(:body) do
          {
            navbar_item: {
              kind: 'presets', preset: 'ideas', landing_page_id: landing_page.id, unknown: 'x'
            }
          }
        end

        schema '$ref' => '#/components/schemas/ConfigurationValidationError'

        run_test! do |response|
          details = JSON.parse(response.body)['error']['details']

          expect(details.keys).to match_array(%w[preset unknown])
        end
      end

      response '422', 'external item without a valid URL' do
        let(:body) { { navbar_item: { kind: 'external', external_url: 'javascript:alert(1)' } } }

        schema '$ref' => '#/components/schemas/ConfigurationValidationError'

        run_test!
      end

      unauthorized_response
      configuration_forbidden_response
    end
  end

  path '/api/configuration/navbar_items/{id}' do
    parameter name: :id, in: :path, type: :integer, required: true

    get 'Show a navigation item' do
      tags 'Configuration Navigation'
      produces 'application/json'
      security [bearer_auth: []]
      description "One navigation item.#{ApiAccessRequirements::CONFIGURATION_REQUIRED}"

      response '200', 'navigation item found' do
        let(:id) { NavbarItem.create!(kind: 'presets', preset: 'proposals').id }

        schema data_schema.call(:navbar_item, navbar_item_schema)

        run_test!
      end

      response '404', 'navigation item not found' do
        let(:id) { 0 }

        run_test!
      end

      unauthorized_response { let(:id) { 0 } }
      configuration_forbidden_response { let(:id) { 0 } }
    end

    patch 'Change a navigation item' do
      tags 'Configuration Navigation'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Changes the given attributes only.#{ApiAccessRequirements::CONFIGURATION_REQUIRED}"
      parameter name: :body, in: :body, required: true, schema: {
        type: :object,
        properties: { navbar_item: navbar_item_input },
        required: ['navbar_item']
      }

      response '200', 'navigation item changed' do
        let(:projekt) { create(:projekt) }
        let(:id) { NavbarItem.create!(kind: 'presets', preset: 'proposals').id }
        let(:body) { { navbar_item: { kind: 'projekts', projekt_id: projekt.id, custom_title: 'Projekt' } } }

        schema data_schema.call(:navbar_item, navbar_item_schema)

        run_test! do
          expect(NavbarItem.find(id).projekt_id).to eq(projekt.id)
        end
      end

      response '422', 'projekt does not exist' do
        let(:id) { NavbarItem.create!(kind: 'presets', preset: 'proposals').id }
        let(:body) { { navbar_item: { kind: 'projekts', projekt_id: 999_999 } } }

        schema '$ref' => '#/components/schemas/ConfigurationValidationError'

        run_test!
      end

      unauthorized_response { let(:id) { 0 } }
      configuration_forbidden_response { let(:id) { 0 } }
    end

    delete 'Delete a navigation item' do
      tags 'Configuration Navigation'
      security [bearer_auth: []]
      description "Deletes the item; its children move up to the top level." \
                  "#{ApiAccessRequirements::CONFIGURATION_REQUIRED}"

      response '204', 'navigation item deleted' do
        let(:id) { NavbarItem.create!(kind: 'presets', preset: 'proposals').id }

        run_test! do
          expect(NavbarItem.exists?(id)).to be(false)
        end
      end

      unauthorized_response { let(:id) { 0 } }
      configuration_forbidden_response { let(:id) { 0 } }
    end
  end

  path '/api/configuration/content_blocks' do
    get 'List homepage and footer content blocks' do
      tags 'Configuration Navigation'
      produces 'application/json'
      security [bearer_auth: []]
      description "The instance-wide HTML blocks of the homepage, the polls pages and the footer, " \
                  "one entry per key whether it was written yet or not." \
                  "#{ApiAccessRequirements::CONFIGURATION_REQUIRED}"

      response '200', 'content blocks listed' do
        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: { content_blocks: { type: :array, items: content_block_schema } }
                 }
               }

        run_test! do |response|
          keys = JSON.parse(response.body)['data']['content_blocks'].map { |block| block['key'] }

          expect(keys).to eq(Api::Configuration::ContentBlocksController::BLOCK_KEYS)
        end
      end

      unauthorized_response
      configuration_forbidden_response
    end
  end

  path '/api/configuration/content_blocks/{key}' do
    parameter name: :key, in: :path, required: true,
              schema: { type: :string, enum: Api::Configuration::ContentBlocksController::BLOCK_KEYS }

    get 'Show a content block' do
      tags 'Configuration Navigation'
      produces 'application/json'
      security [bearer_auth: []]
      description "One block by its key.#{ApiAccessRequirements::CONFIGURATION_REQUIRED}"

      response '200', 'content block found' do
        let(:key) { 'home_page_1' }

        schema data_schema.call(:content_block, content_block_schema)

        run_test!
      end

      response '404', 'not an instance-wide block' do
        let(:key) { 'projekt_content_block_1_1_1' }

        run_test!
      end

      unauthorized_response { let(:key) { 'home_page_1' } }
      configuration_forbidden_response { let(:key) { 'home_page_1' } }
    end

    patch 'Change a content block' do
      tags 'Configuration Navigation'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Writes the block's HTML and visibility. The HTML is sanitized like in the editor: " \
                  "scripts and unsupported markup are removed (`body_stripped` reports it). " \
                  "Times are ISO 8601.#{ApiAccessRequirements::CONFIGURATION_REQUIRED}"
      parameter name: :body, in: :body, required: true, schema: {
        type: :object,
        properties: {
          content_block: {
            type: :object,
            properties: {
              body: {
                type: :string,
                nullable: true,
                maxLength: Api::Configuration::ContentBlocksController::BODY_MAX_LENGTH
              },
              visible: { type: :boolean },
              visible_from: { type: :string, format: :date_time, nullable: true },
              visible_until: { type: :string, format: :date_time, nullable: true },
              margin_bottom: {
                type: :integer,
                minimum: SiteCustomization::ContentBlock::MIN_MARGIN_BOTTOM,
                maximum: Api::Configuration::ContentBlocksController::MARGIN_BOTTOM_MAX
              }
            }
          }
        },
        required: ['content_block']
      }

      response '200', 'content block written, scripts removed' do
        let(:key) { 'home_page_2' }
        let(:body) do
          {
            content_block: {
              body: '<p>Welcome</p><script>alert(1)</script>',
              visible: true,
              visible_from: '2026-11-01T08:00:00+01:00',
              margin_bottom: 40
            }
          }
        end

        schema data_schema.call(:content_block, content_block_schema)

        run_test! do |response|
          content_block = JSON.parse(response.body)['data']['content_block']
          stored_block = SiteCustomization::ContentBlock.find_by(name: 'custom', key: 'home_page_2')

          expect(content_block['body']).to include('Welcome')
          expect(content_block['body']).not_to include('script')
          expect(content_block['body_stripped']).to be(true)
          expect(stored_block.body).not_to include('script')
          expect(stored_block.margin_bottom).to eq(40)
          expect(Audit.where(associated: stored_block).or(Audit.where(auditable: stored_block)).last.comment)
            .to eq("api_client:#{api_client.id}")
        end
      end

      response '200', 'footer contact block written' do
        let(:key) { 'footer' }
        let(:body) { { content_block: { body: '<p>Contact</p>' } } }

        run_test! do
          footer_body = SiteCustomization::ContentBlock.block_for('footer', I18n.default_locale)

          expect(footer_body).to include('Contact')
        end
      end

      response '422', 'invalid visibility or margin' do
        let(:key) { 'home_page_1' }
        let(:body) do
          { content_block: { visible: 'sometimes', visible_until: 'tomorrow', margin_bottom: 2 } }
        end

        schema '$ref' => '#/components/schemas/ConfigurationValidationError'

        run_test! do |response|
          details = JSON.parse(response.body)['error']['details']

          expect(details.keys).to match_array(%w[visible visible_until margin_bottom])
        end
      end

      unauthorized_response { let(:key) { 'home_page_1' } }
      configuration_forbidden_response { let(:key) { 'home_page_1' } }
    end
  end

  path '/api/configuration/content_cards' do
    get 'List homepage cards' do
      tags 'Configuration Navigation'
      produces 'application/json'
      security [bearer_auth: []]
      description "The content cards of the homepage, or of a landing page with `landing_page_id`. " \
                  "Missing cards are created with their defaults." \
                  "#{ApiAccessRequirements::CONFIGURATION_REQUIRED}"
      parameter name: :landing_page_id, in: :query, type: :integer, required: false

      response '200', 'homepage cards listed' do
        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: { content_cards: { type: :array, items: content_card_schema } }
                 }
               }

        run_test! do |response|
          kinds = JSON.parse(response.body)['data']['content_cards'].map { |card| card['kind'] }

          expect(kinds).to match_array(SiteCustomization::ContentCard::KINDS)
        end
      end

      response '200', 'landing page cards listed' do
        let(:landing_page_id) { create_landing_page.id }

        run_test! do |response|
          kinds = JSON.parse(response.body)['data']['content_cards'].map { |card| card['kind'] }

          expect(kinds).not_to include('latest_user_activity')
        end
      end

      unauthorized_response
      configuration_forbidden_response
    end
  end

  path '/api/configuration/content_cards/{id}' do
    parameter name: :id, in: :path, type: :integer, required: true

    get 'Show a homepage card' do
      tags 'Configuration Navigation'
      produces 'application/json'
      security [bearer_auth: []]
      description "One content card.#{ApiAccessRequirements::CONFIGURATION_REQUIRED}"

      response '200', 'card found' do
        let(:id) { SiteCustomization::ContentCard.get_or_create_for_homepage.first.id }

        schema data_schema.call(:content_card, content_card_schema)

        run_test!
      end

      unauthorized_response { let(:id) { 0 } }
      configuration_forbidden_response { let(:id) { 0 } }
    end

    patch 'Change a homepage card' do
      tags 'Configuration Navigation'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Switches a card on or off, moves it, renames it per language or changes its " \
                  "limits. Only the limits of the card's kind can be set." \
                  "#{ApiAccessRequirements::CONFIGURATION_REQUIRED}"
      parameter name: :body, in: :body, required: true, schema: {
        type: :object,
        properties: {
          content_card: {
            type: :object,
            properties: {
              active: { type: :boolean },
              position: { type: :integer, minimum: 1 },
              settings: {
                type: :object,
                description: "Limits per kind: #{content_card_limits_description}",
                additionalProperties: { type: :integer, minimum: 0 }
              },
              translations: Schemas::Configuration.translations_object(title: { type: :string })
            }
          }
        },
        required: ['content_card']
      }

      response '200', 'card changed' do
        let(:content_card) do
          SiteCustomization::ContentCard
            .get_or_create_for_homepage
            .find { |card| card.kind == 'latest_resources' }
        end
        let(:id) { content_card.id }
        let(:body) do
          {
            content_card: {
              active: false,
              position: 3,
              settings: { debates_limit: 5 },
              translations: { de: { title: 'Neu' }, en: { title: 'New' } }
            }
          }
        end

        schema data_schema.call(:content_card, content_card_schema)

        run_test! do |response|
          content_card_data = JSON.parse(response.body)['data']['content_card']

          expect(content_card_data['active']).to be(false)
          expect(content_card_data['settings']['debates_limit']).to eq(5)
          expect(content_card_data['settings']['proposals_limit']).to eq(3)
          expect(content_card_data['translations']['en']['title']).to eq('New')
          expect_audited_by_client(content_card)
        end
      end

      response '422', 'setting of another kind' do
        let(:id) do
          SiteCustomization::ContentCard.get_or_create_for_homepage.find { |card| card.kind == 'events' }.id
        end
        let(:body) { { content_card: { settings: { debates_limit: 2, limit: -1 } } } }

        schema '$ref' => '#/components/schemas/ConfigurationValidationError'

        run_test! do |response|
          details = JSON.parse(response.body)['error']['details']

          expect(details.keys).to match_array(%w[settings.debates_limit settings.limit])
        end
      end

      unauthorized_response { let(:id) { 0 } }
      configuration_forbidden_response { let(:id) { 0 } }
    end
  end

  path '/api/configuration/banners' do
    get 'List banners' do
      tags 'Configuration Navigation'
      produces 'application/json'
      security [bearer_auth: []]
      description "Banners, newest first.#{ApiAccessRequirements::CONFIGURATION_REQUIRED}"
      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :per_page, in: :query, type: :integer, required: false

      response '200', 'banners listed' do
        before { create_banner }

        schema type: :object,
               properties: {
                 data: { type: :object, properties: { banners: { type: :array, items: banner_schema } } },
                 pagination: Schemas::Miscellaneous::PAGINATION_RESPONSE_SCHEMA
               }

        run_test! do |response|
          expect(JSON.parse(response.body)['data']['banners'].first['active']).to be(true)
        end
      end

      unauthorized_response
      configuration_forbidden_response
    end

    post 'Create a banner' do
      tags 'Configuration Navigation'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Adds a banner. Title (at least 2 characters) and description are required for " \
                  "every language sent.#{ApiAccessRequirements::CONFIGURATION_REQUIRED}"
      parameter name: :body, in: :body, required: true, schema: {
        type: :object,
        properties: { banner: banner_input },
        required: ['banner']
      }

      response '201', 'banner created' do
        let(:body) do
          {
            banner: {
              target_url: '/proposals',
              post_started_at: '2026-11-01',
              post_ended_at: '2026-11-30',
              background_color: '#004a83',
              font_color: '#ffffff',
              web_section_ids: [WebSection.find_by(name: 'homepage').id],
              translations: {
                de: { title: 'Jetzt mitmachen', description: 'Neue Vorschläge' },
                en: { title: 'Take part', description: 'New proposals' }
              }
            }
          }
        end

        schema data_schema.call(:banner, banner_schema)

        run_test! do |response|
          banner = Banner.find(JSON.parse(response.body)['data']['banner']['id'])

          expect(banner.web_sections.map(&:name)).to eq(['homepage'])
          expect(Globalize.with_locale(:en) { banner.title }).to eq('Take part')
          expect_audited_by_client(banner)
        end
      end

      response '422', 'wrong value types' do
        let(:body) do
          {
            banner: {
              target_url: 'ftp://example.com',
              post_started_at: '01.11.2026',
              background_color: 'blue',
              web_section_ids: [0],
              translations: { xx: { title: 'Bonjour' } }
            }
          }
        end

        schema '$ref' => '#/components/schemas/ConfigurationValidationError'

        run_test! do |response|
          details = JSON.parse(response.body)['error']['details']

          expect(details.keys).to match_array(
            %w[target_url post_started_at background_color web_section_ids translations]
          )
        end
      end

      unauthorized_response
      configuration_forbidden_response
    end
  end

  path '/api/configuration/banners/{id}' do
    parameter name: :id, in: :path, type: :integer, required: true

    get 'Show a banner' do
      tags 'Configuration Navigation'
      produces 'application/json'
      security [bearer_auth: []]
      description "One banner.#{ApiAccessRequirements::CONFIGURATION_REQUIRED}"

      response '200', 'banner found' do
        let(:id) { create_banner.id }

        schema data_schema.call(:banner, banner_schema)

        run_test!
      end

      response '404', 'banner not found' do
        let(:id) { 0 }

        run_test!
      end

      unauthorized_response { let(:id) { 0 } }
      configuration_forbidden_response { let(:id) { 0 } }
    end

    patch 'Change a banner' do
      tags 'Configuration Navigation'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Changes the given attributes and languages only." \
                  "#{ApiAccessRequirements::CONFIGURATION_REQUIRED}"
      parameter name: :body, in: :body, required: true, schema: {
        type: :object,
        properties: { banner: banner_input },
        required: ['banner']
      }

      response '200', 'banner changed' do
        let(:id) { create_banner.id }
        let(:body) { { banner: { post_ended_at: '2027-01-31', translations: { en: { title: 'Changed' } } } } }

        schema data_schema.call(:banner, banner_schema)

        run_test! do
          banner = Banner.find(id)

          expect(banner.post_ended_at).to eq(Date.new(2027, 1, 31))
          expect(Globalize.with_locale(:en) { banner.title }).to eq('Changed')
        end
      end

      response '422', 'new language without its required texts' do
        let(:id) { create_banner.id }
        let(:body) { { banner: { translations: { de: { title: 'Nur Titel' } } } } }

        schema '$ref' => '#/components/schemas/ConfigurationValidationError'

        run_test! do |response|
          expect(JSON.parse(response.body)['error']['details'].keys).to eq(['translations.de.description'])
        end
      end

      unauthorized_response { let(:id) { 0 } }
      configuration_forbidden_response { let(:id) { 0 } }
    end

    delete 'Delete a banner' do
      tags 'Configuration Navigation'
      security [bearer_auth: []]
      description "Hides the banner (soft delete).#{ApiAccessRequirements::CONFIGURATION_REQUIRED}"

      response '204', 'banner deleted' do
        let(:id) { create_banner.id }

        run_test! do
          expect(Banner.find_by(id: id)).to be_nil
          expect(Banner.with_hidden.find(id).hidden_at).to be_present
        end
      end

      unauthorized_response { let(:id) { 0 } }
      configuration_forbidden_response { let(:id) { 0 } }
    end
  end

  path '/api/configuration/modal_notifications' do
    get 'List modal notifications' do
      tags 'Configuration Navigation'
      produces 'application/json'
      security [bearer_auth: []]
      description "Modal notifications, newest first. The newest one whose period covers today " \
                  "is shown to visitors.#{ApiAccessRequirements::CONFIGURATION_REQUIRED}"
      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :per_page, in: :query, type: :integer, required: false

      response '200', 'modal notifications listed' do
        before { create_modal_notification }

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: { modal_notifications: { type: :array, items: modal_notification_schema } }
                 },
                 pagination: Schemas::Miscellaneous::PAGINATION_RESPONSE_SCHEMA
               }

        run_test! do |response|
          expect(JSON.parse(response.body)['data']['modal_notifications'].first['current']).to be(true)
        end
      end

      unauthorized_response
      configuration_forbidden_response
    end

    post 'Create a modal notification' do
      tags 'Configuration Navigation'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Adds a modal notification for a period. The HTML is sanitized before it is " \
                  "stored.#{ApiAccessRequirements::CONFIGURATION_REQUIRED}"
      parameter name: :body, in: :body, required: true, schema: {
        type: :object,
        properties: { modal_notification: modal_notification_input },
        required: ['modal_notification']
      }

      response '201', 'modal notification created, scripts removed' do
        let(:body) do
          {
            modal_notification: {
              active_from: '2026-11-01',
              active_to: '2026-11-30',
              translations: {
                de: { title: 'Hinweis', html_content: '<p>Wartung</p><script>alert(1)</script>' }
              }
            }
          }
        end

        schema data_schema.call(:modal_notification, modal_notification_schema)

        run_test! do |response|
          modal_notification = ModalNotification.find(
            JSON.parse(response.body)['data']['modal_notification']['id']
          )

          expect(modal_notification.html_content).to include('Wartung')
          expect(modal_notification.html_content).not_to include('script')
          expect_audited_by_client(modal_notification)
        end
      end

      response '422', 'period missing or reversed' do
        let(:body) { { modal_notification: { active_from: '2026-11-30', active_to: '2026-11-01' } } }

        schema '$ref' => '#/components/schemas/ConfigurationValidationError'

        run_test! do |response|
          expect(JSON.parse(response.body)['error']['details'].keys).to eq(['active_to'])
        end
      end

      unauthorized_response
      configuration_forbidden_response
    end
  end

  path '/api/configuration/modal_notifications/{id}' do
    parameter name: :id, in: :path, type: :integer, required: true

    get 'Show a modal notification' do
      tags 'Configuration Navigation'
      produces 'application/json'
      security [bearer_auth: []]
      description "One modal notification.#{ApiAccessRequirements::CONFIGURATION_REQUIRED}"

      response '200', 'modal notification found' do
        let(:id) { create_modal_notification.id }

        schema data_schema.call(:modal_notification, modal_notification_schema)

        run_test!
      end

      response '404', 'modal notification not found' do
        let(:id) { 0 }

        run_test!
      end

      unauthorized_response { let(:id) { 0 } }
      configuration_forbidden_response { let(:id) { 0 } }
    end

    patch 'Change a modal notification' do
      tags 'Configuration Navigation'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Changes the given attributes and languages only." \
                  "#{ApiAccessRequirements::CONFIGURATION_REQUIRED}"
      parameter name: :body, in: :body, required: true, schema: {
        type: :object,
        properties: { modal_notification: modal_notification_input },
        required: ['modal_notification']
      }

      response '200', 'modal notification changed' do
        let(:id) { create_modal_notification.id }
        let(:body) { { modal_notification: { active_to: (Date.current + 30).iso8601 } } }

        schema data_schema.call(:modal_notification, modal_notification_schema)

        run_test! do
          expect(ModalNotification.find(id).active_to).to eq(Date.current + 30)
        end
      end

      unauthorized_response { let(:id) { 0 } }
      configuration_forbidden_response { let(:id) { 0 } }
    end

    delete 'Delete a modal notification' do
      tags 'Configuration Navigation'
      security [bearer_auth: []]
      description "Deletes the modal notification.#{ApiAccessRequirements::CONFIGURATION_REQUIRED}"

      response '204', 'modal notification deleted' do
        let(:id) { create_modal_notification.id }

        run_test! do
          expect(ModalNotification.exists?(id)).to be(false)
        end
      end

      unauthorized_response { let(:id) { 0 } }
      configuration_forbidden_response { let(:id) { 0 } }
    end
  end
end
