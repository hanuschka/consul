# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Configuration Catalogs API', type: :request, openapi_spec: 'v1/swagger.yaml' do
  let!(:api_client) { create_configuration_api_client }
  let(:Authorization) { "Bearer #{api_client.access_token}" }

  def expect_audited_by_client(audit)
    expect(audit.comment).to eq("api_client:#{api_client.id}")
    expect(audit.user).to eq(api_client.content_author)
  end

  name_translations_schema = {
    type: :object,
    description: 'Names per language, keyed by locale',
    additionalProperties: {
      type: :object,
      properties: { name: { type: :string, nullable: true } }
    }
  }

  name_translations_input = {
    type: :object,
    description: 'Names per language, keyed by locale (`de`, `en`). Languages left out stay as ' \
                 'they are; sending more than one language skips machine translation.',
    additionalProperties: false,
    properties: {
      de: { type: :object, properties: { name: { type: :string } } },
      en: { type: :object, properties: { name: { type: :string } } }
    }
  }

  geozone_schema = {
    type: :object,
    properties: {
      id: { type: :integer, example: 3 },
      name: { type: :string, example: 'Altstadt' },
      external_code: { type: :string, nullable: true, example: 'D-01' },
      html_map_coordinates: {
        type: :string,
        nullable: true,
        description: 'Polygon of the area on the map image, as comma-separated pixel coordinates',
        example: '10,20,120,20,120,90,10,90'
      },
      created_at: { type: :string, format: :date_time },
      updated_at: { type: :string, format: :date_time }
    },
    required: %w[id name]
  }

  geozone_input = {
    type: :object,
    properties: {
      geozone: {
        type: :object,
        properties: {
          name: { type: :string, example: 'Altstadt' },
          external_code: { type: :string, nullable: true },
          html_map_coordinates: { type: :string, nullable: true, pattern: '^\s*\d+(\s*,\s*\d+)*\s*$' }
        }
      }
    },
    required: ['geozone']
  }

  tag_category_schema = {
    type: :object,
    properties: {
      id: { type: :integer, example: 12 },
      name: { type: :string, example: 'Mobilität' },
      taggings_count: { type: :integer, example: 4 }
    },
    required: %w[id name]
  }

  tag_category_input = {
    type: :object,
    properties: {
      tag_category: {
        type: :object,
        properties: { name: { type: :string, maxLength: 160, example: 'Mobilität' } },
        required: ['name']
      }
    },
    required: ['tag_category']
  }

  age_range_schema = {
    type: :object,
    properties: {
      id: { type: :integer, example: 2 },
      order: { type: :integer, nullable: true, example: 1 },
      min_age: { type: :integer, nullable: true, description: 'Blank means open ended', example: 18 },
      max_age: { type: :integer, nullable: true, description: 'Blank means open ended', example: 29 },
      only_for_stats: { type: :boolean, description: 'Used only to group statistics, not to restrict phases' },
      translations: name_translations_schema
    },
    required: %w[id translations]
  }

  age_range_input = {
    type: :object,
    properties: {
      age_range: {
        type: :object,
        properties: {
          order: { type: :integer, nullable: true },
          min_age: { type: :integer, nullable: true, minimum: 0 },
          max_age: { type: :integer, nullable: true, minimum: 0 },
          only_for_stats: { type: :boolean },
          translations: name_translations_input
        }
      }
    },
    required: ['age_range']
  }

  individual_group_schema = {
    type: :object,
    properties: {
      id: { type: :integer, example: 5 },
      kind: { type: :string, enum: IndividualGroup.kinds.keys },
      visible: { type: :boolean },
      translations: name_translations_schema
    },
    required: %w[id kind translations]
  }

  path '/api/configuration/geozones' do
    get 'List geozones' do
      tags 'Configuration Catalogs'
      produces 'application/json'
      security [bearer_auth: []]
      description "The districts of the instance. Census codes and postal codes belong to " \
                  "verification and are not part of the API.#{ApiAccessRequirements::CONFIGURATION_REQUIRED}"
      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :per_page, in: :query, type: :integer, required: false

      response '200', 'geozones listed' do
        before { Geozone.create!(name: 'Altstadt') }

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: { geozones: { type: :array, items: geozone_schema } },
                   required: ['geozones']
                 },
                 pagination: { type: :object }
               },
               required: ['data']

        run_test! do |response|
          names = JSON.parse(response.body)['data']['geozones'].map { |geozone| geozone['name'] }

          expect(names).to include('Altstadt')
        end
      end

      unauthorized_response
      configuration_forbidden_response
    end

    post 'Create a geozone' do
      tags 'Configuration Catalogs'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Adds a district.#{ApiAccessRequirements::CONFIGURATION_REQUIRED}"
      parameter name: :body, in: :body, required: true, schema: geozone_input

      response '201', 'geozone created' do
        let(:body) { { geozone: { name: 'Neustadt', external_code: 'D-02', html_map_coordinates: '1,2,3,4' } } }

        schema type: :object, properties: { data: { type: :object, properties: { geozone: geozone_schema } } }

        run_test! do |response|
          geozone = Geozone.find(JSON.parse(response.body)['data']['geozone']['id'])

          expect(geozone.name).to eq('Neustadt')
          expect_audited_by_client(geozone.audits.last)
        end
      end

      response '422', 'name missing or coordinates malformed' do
        let(:body) { { geozone: { name: '', html_map_coordinates: '1,2,"onmouseover' } } }

        schema '$ref' => '#/components/schemas/ConfigurationValidationError'

        run_test!
      end

      unauthorized_response
      configuration_forbidden_response
    end
  end

  path '/api/configuration/geozones/{id}' do
    parameter name: :id, in: :path, type: :integer, required: true

    let(:geozone) { Geozone.create!(name: 'Altstadt') }

    get 'Show a geozone' do
      tags 'Configuration Catalogs'
      produces 'application/json'
      security [bearer_auth: []]
      description "One district.#{ApiAccessRequirements::CONFIGURATION_REQUIRED}"

      response '200', 'geozone found' do
        let(:id) { geozone.id }

        schema type: :object, properties: { data: { type: :object, properties: { geozone: geozone_schema } } }

        run_test!
      end

      response '404', 'geozone not found' do
        let(:id) { 0 }

        run_test!
      end

      unauthorized_response { let(:id) { geozone.id } }
      configuration_forbidden_response { let(:id) { geozone.id } }
    end

    patch 'Update a geozone' do
      tags 'Configuration Catalogs'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Renames a district or changes its code or map area.#{ApiAccessRequirements::CONFIGURATION_REQUIRED}"
      parameter name: :body, in: :body, required: true, schema: geozone_input

      response '200', 'geozone updated' do
        let(:id) { geozone.id }
        let(:body) { { geozone: { name: 'Altstadt-Nord', census_code: '99', postal_codes: '12345' } } }

        schema type: :object, properties: { data: { type: :object, properties: { geozone: geozone_schema } } }

        run_test! do
          geozone.reload

          expect(geozone.name).to eq('Altstadt-Nord')
          expect(geozone.census_code).to be_nil
          expect(geozone.postal_codes).to be_nil
          expect_audited_by_client(geozone.audits.last)
          expect(geozone.audits.last.audited_changes['name']).to eq(%w[Altstadt Altstadt-Nord])
        end
      end

      response '422', 'invalid map coordinates' do
        let(:id) { geozone.id }
        let(:body) { { geozone: { html_map_coordinates: 'north' } } }

        schema '$ref' => '#/components/schemas/ConfigurationValidationError'

        run_test!
      end

      response '404', 'geozone not found' do
        let(:id) { 0 }
        let(:body) { { geozone: { name: 'Nowhere' } } }

        run_test!
      end

      unauthorized_response { let(:id) { geozone.id } }
      configuration_forbidden_response { let(:id) { geozone.id } }
    end

    delete 'Delete a geozone' do
      tags 'Configuration Catalogs'
      produces 'application/json'
      security [bearer_auth: []]
      description "Deletes a district that nothing refers to any more: no user, contribution, " \
                  "poll, projekt or phase.#{ApiAccessRequirements::CONFIGURATION_REQUIRED}"

      response '204', 'geozone deleted' do
        let(:id) { geozone.id }

        run_test! do
          expect(Geozone.exists?(geozone.id)).to be(false)
        end
      end

      response '422', 'geozone still in use' do
        let(:id) { geozone.id }

        before { create(:user).update_column(:geozone_id, geozone.id) }

        schema '$ref' => '#/components/schemas/ConfigurationValidationError'

        run_test! do
          expect(Geozone.exists?(geozone.id)).to be(true)
        end
      end

      unauthorized_response { let(:id) { geozone.id } }
      configuration_forbidden_response { let(:id) { geozone.id } }
    end
  end

  path '/api/configuration/tag_categories' do
    get 'List tag categories' do
      tags 'Configuration Catalogs'
      produces 'application/json'
      security [bearer_auth: []]
      description "The categories offered when tagging contributions. Tags users add themselves " \
                  "are not listed.#{ApiAccessRequirements::CONFIGURATION_REQUIRED}"
      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :per_page, in: :query, type: :integer, required: false

      response '200', 'tag categories listed' do
        before do
          Tag.create!(name: 'Mobilität', kind: 'category')
          Tag.create!(name: 'user tag')
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: { tag_categories: { type: :array, items: tag_category_schema } },
                   required: ['tag_categories']
                 },
                 pagination: { type: :object }
               },
               required: ['data']

        run_test! do |response|
          names = JSON.parse(response.body)['data']['tag_categories'].map { |tag| tag['name'] }

          expect(names).to include('Mobilität')
          expect(names).not_to include('user tag')
        end
      end

      unauthorized_response
      configuration_forbidden_response
    end

    post 'Create a tag category' do
      tags 'Configuration Catalogs'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Adds a category. A name already used by a tag that users added is refused " \
                  "rather than turning that tag into a category.#{ApiAccessRequirements::CONFIGURATION_REQUIRED}"
      parameter name: :body, in: :body, required: true, schema: tag_category_input

      response '201', 'tag category created' do
        let(:body) { { tag_category: { name: 'Klima' } } }

        schema type: :object,
               properties: { data: { type: :object, properties: { tag_category: tag_category_schema } } }

        run_test! do |response|
          tag = Tag.find(JSON.parse(response.body)['data']['tag_category']['id'])

          expect(tag).to be_category
          expect_audited_by_client(tag.audits.last)
        end
      end

      response '422', 'name already used by a user tag' do
        before { Tag.create!(name: 'Klima') }

        let(:body) { { tag_category: { name: 'Klima' } } }

        schema '$ref' => '#/components/schemas/ConfigurationValidationError'

        run_test! do
          expect(Tag.find_by(name: 'Klima').kind).to be_nil
        end
      end

      response '422', 'name missing' do
        let(:body) { { tag_category: { name: '' } } }

        schema '$ref' => '#/components/schemas/ConfigurationValidationError'

        run_test!
      end

      unauthorized_response
      configuration_forbidden_response
    end
  end

  path '/api/configuration/tag_categories/{id}' do
    parameter name: :id, in: :path, type: :integer, required: true

    let(:tag_category) { Tag.create!(name: 'Mobilität', kind: 'category') }

    get 'Show a tag category' do
      tags 'Configuration Catalogs'
      produces 'application/json'
      security [bearer_auth: []]
      description "One category.#{ApiAccessRequirements::CONFIGURATION_REQUIRED}"

      response '200', 'tag category found' do
        let(:id) { tag_category.id }

        schema type: :object,
               properties: { data: { type: :object, properties: { tag_category: tag_category_schema } } }

        run_test!
      end

      response '404', 'not a category' do
        let(:id) { Tag.create!(name: 'user tag').id }

        run_test!
      end

      unauthorized_response { let(:id) { tag_category.id } }
      configuration_forbidden_response { let(:id) { tag_category.id } }
    end

    patch 'Rename a tag category' do
      tags 'Configuration Catalogs'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Renames a category.#{ApiAccessRequirements::CONFIGURATION_REQUIRED}"
      parameter name: :body, in: :body, required: true, schema: tag_category_input

      response '200', 'tag category renamed' do
        let(:id) { tag_category.id }
        let(:body) { { tag_category: { name: 'Verkehr' } } }

        schema type: :object,
               properties: { data: { type: :object, properties: { tag_category: tag_category_schema } } }

        run_test! do
          expect(tag_category.reload.name).to eq('Verkehr')
          expect(tag_category.audits.last.audited_changes['name']).to eq(%w[Mobilität Verkehr])
        end
      end

      response '422', 'name already used by a user tag' do
        before { Tag.create!(name: 'Verkehr') }

        let(:id) { tag_category.id }
        let(:body) { { tag_category: { name: 'Verkehr' } } }

        schema '$ref' => '#/components/schemas/ConfigurationValidationError'

        run_test!
      end

      response '404', 'tag category not found' do
        let(:id) { 0 }
        let(:body) { { tag_category: { name: 'Verkehr' } } }

        run_test!
      end

      unauthorized_response { let(:id) { tag_category.id } }
      configuration_forbidden_response { let(:id) { tag_category.id } }
    end

    delete 'Delete a tag category' do
      tags 'Configuration Catalogs'
      produces 'application/json'
      security [bearer_auth: []]
      description "Deletes a category; contributions tagged with it lose the tag." \
                  "#{ApiAccessRequirements::CONFIGURATION_REQUIRED}"

      response '204', 'tag category deleted' do
        let(:id) { tag_category.id }

        run_test! do
          expect(Tag.exists?(tag_category.id)).to be(false)
        end
      end

      response '404', 'user tags cannot be deleted here' do
        let(:id) { Tag.create!(name: 'user tag').id }

        run_test!
      end

      unauthorized_response { let(:id) { tag_category.id } }
      configuration_forbidden_response { let(:id) { tag_category.id } }
    end
  end

  path '/api/configuration/age_ranges' do
    get 'List age ranges' do
      tags 'Configuration Catalogs'
      produces 'application/json'
      security [bearer_auth: []]
      description "Age ranges used to restrict phases or to group statistics, in their display " \
                  "order.#{ApiAccessRequirements::CONFIGURATION_REQUIRED}"
      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :per_page, in: :query, type: :integer, required: false

      response '200', 'age ranges listed' do
        before { AgeRange.create!(order: 1, min_age: 18, max_age: 29, name: '18-29') }

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: { age_ranges: { type: :array, items: age_range_schema } },
                   required: ['age_ranges']
                 },
                 pagination: { type: :object }
               },
               required: ['data']

        run_test!
      end

      unauthorized_response
      configuration_forbidden_response
    end

    post 'Create an age range' do
      tags 'Configuration Catalogs'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Adds an age range. Leave `min_age` or `max_age` empty for an open-ended " \
                  "range.#{ApiAccessRequirements::CONFIGURATION_REQUIRED}"
      parameter name: :body, in: :body, required: true, schema: age_range_input

      response '201', 'age range created' do
        let(:body) do
          {
            age_range: {
              order: 2,
              min_age: 30,
              max_age: 49,
              only_for_stats: true,
              translations: { de: { name: '30 bis 49' }, en: { name: '30 to 49' } }
            }
          }
        end

        schema type: :object, properties: { data: { type: :object, properties: { age_range: age_range_schema } } }

        run_test! do |response|
          age_range = JSON.parse(response.body)['data']['age_range']

          expect(age_range['translations']).to eq(
            'de' => { 'name' => '30 bis 49' },
            'en' => { 'name' => '30 to 49' }
          )
          expect(age_range['only_for_stats']).to be(true)
          expect_audited_by_client(AgeRange.find(age_range['id']).audits.last)
        end
      end

      response '422', 'min age above max age' do
        let(:body) { { age_range: { min_age: 50, max_age: 20, translations: { de: { name: 'Falsch' } } } } }

        schema '$ref' => '#/components/schemas/ConfigurationValidationError'

        run_test! do
          expect(AgeRange.count).to eq(0)
        end
      end

      response '422', 'unsupported language' do
        let(:body) { { age_range: { translations: { xx: { name: 'Falsch' } } } } }

        schema '$ref' => '#/components/schemas/ConfigurationValidationError'

        run_test!
      end

      unauthorized_response
      configuration_forbidden_response
    end
  end

  path '/api/configuration/age_ranges/{id}' do
    parameter name: :id, in: :path, type: :integer, required: true

    let(:age_range) { AgeRange.create!(order: 1, min_age: 18, max_age: 29, name: '18-29') }

    get 'Show an age range' do
      tags 'Configuration Catalogs'
      produces 'application/json'
      security [bearer_auth: []]
      description "One age range.#{ApiAccessRequirements::CONFIGURATION_REQUIRED}"

      response '200', 'age range found' do
        let(:id) { age_range.id }

        schema type: :object, properties: { data: { type: :object, properties: { age_range: age_range_schema } } }

        run_test!
      end

      response '404', 'age range not found' do
        let(:id) { 0 }

        run_test!
      end

      unauthorized_response { let(:id) { age_range.id } }
      configuration_forbidden_response { let(:id) { age_range.id } }
    end

    patch 'Update an age range' do
      tags 'Configuration Catalogs'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Changes the bounds, order, use or names of an age range." \
                  "#{ApiAccessRequirements::CONFIGURATION_REQUIRED}"
      parameter name: :body, in: :body, required: true, schema: age_range_input

      response '200', 'age range updated' do
        let(:id) { age_range.id }
        let(:body) { { age_range: { max_age: 34, translations: { de: { name: '18 bis 34' } } } } }

        schema type: :object, properties: { data: { type: :object, properties: { age_range: age_range_schema } } }

        run_test! do
          age_range.reload

          expect(age_range.max_age).to eq(34)
          expect(age_range.translations.find_by(locale: :de).name).to eq('18 bis 34')
          expect(age_range.audits.last.audited_changes['max_age']).to eq([29, 34])
        end
      end

      response '422', 'max age below min age' do
        let(:id) { age_range.id }
        let(:body) { { age_range: { max_age: 10 } } }

        schema '$ref' => '#/components/schemas/ConfigurationValidationError'

        run_test! do
          expect(age_range.reload.max_age).to eq(29)
        end
      end

      response '404', 'age range not found' do
        let(:id) { 0 }
        let(:body) { { age_range: { max_age: 34 } } }

        run_test!
      end

      unauthorized_response { let(:id) { age_range.id } }
      configuration_forbidden_response { let(:id) { age_range.id } }
    end

    delete 'Delete an age range' do
      tags 'Configuration Catalogs'
      produces 'application/json'
      security [bearer_auth: []]
      description "Deletes an age range no phase uses, neither as a restriction nor for " \
                  "statistics.#{ApiAccessRequirements::CONFIGURATION_REQUIRED}"

      response '204', 'age range deleted' do
        let(:id) { age_range.id }

        run_test! do
          expect(AgeRange.exists?(age_range.id)).to be(false)
        end
      end

      response '422', 'age range restricts a phase' do
        let(:id) { age_range.id }

        before { create(:projekt_phase).update_column(:age_range_id, age_range.id) }

        schema '$ref' => '#/components/schemas/ConfigurationValidationError'

        run_test! do
          expect(AgeRange.exists?(age_range.id)).to be(true)
        end
      end

      unauthorized_response { let(:id) { age_range.id } }
      configuration_forbidden_response { let(:id) { age_range.id } }
    end
  end

  path '/api/configuration/individual_groups' do
    get 'List individual groups' do
      tags 'Configuration Catalogs'
      produces 'application/json'
      security [bearer_auth: []]
      description "The groups participants can be assigned to. Only their names are " \
                  "configurable.#{ApiAccessRequirements::CONFIGURATION_REQUIRED}"
      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :per_page, in: :query, type: :integer, required: false

      response '200', 'individual groups listed' do
        before { create(:individual_group) }

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: { individual_groups: { type: :array, items: individual_group_schema } },
                   required: ['individual_groups']
                 },
                 pagination: { type: :object }
               },
               required: ['data']

        run_test!
      end

      unauthorized_response
      configuration_forbidden_response
    end

    post 'Create an individual group' do
      tags 'Configuration Catalogs'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Adds a group. `kind` and `visible` are set once here because a group needs " \
                  "them; afterwards only the name can be changed through the API. Groups " \
                  "cannot be deleted through the API.#{ApiAccessRequirements::CONFIGURATION_REQUIRED}"
      parameter name: :body, in: :body, required: true, schema: {
        type: :object,
        properties: {
          individual_group: {
            type: :object,
            properties: {
              kind: { type: :string, enum: IndividualGroup.kinds.keys },
              visible: { type: :boolean },
              translations: name_translations_input
            },
            required: %w[kind translations]
          }
        },
        required: ['individual_group']
      }

      response '201', 'individual group created' do
        let(:body) do
          { individual_group: { kind: 'soft', visible: true, translations: { de: { name: 'Seniorenbeirat' } } } }
        end

        schema type: :object,
               properties: { data: { type: :object, properties: { individual_group: individual_group_schema } } }

        run_test! do |response|
          individual_group = JSON.parse(response.body)['data']['individual_group']

          expect(individual_group).to include('kind' => 'soft', 'visible' => true)
          expect(individual_group['translations']['de']['name']).to eq('Seniorenbeirat')
        end
      end

      response '422', 'unknown kind' do
        let(:body) { { individual_group: { kind: 'secret', translations: { de: { name: 'Gruppe' } } } } }

        schema '$ref' => '#/components/schemas/ConfigurationValidationError'

        run_test!
      end

      response '422', 'name missing' do
        let(:body) { { individual_group: { kind: 'hard', translations: { de: { name: '' } } } } }

        schema '$ref' => '#/components/schemas/ConfigurationValidationError'

        run_test!
      end

      unauthorized_response
      configuration_forbidden_response
    end
  end

  path '/api/configuration/individual_groups/{id}' do
    parameter name: :id, in: :path, type: :integer, required: true

    let(:individual_group) { create(:individual_group, name: 'Jugendrat') }

    get 'Show an individual group' do
      tags 'Configuration Catalogs'
      produces 'application/json'
      security [bearer_auth: []]
      description "One group.#{ApiAccessRequirements::CONFIGURATION_REQUIRED}"

      response '200', 'individual group found' do
        let(:id) { individual_group.id }

        schema type: :object,
               properties: { data: { type: :object, properties: { individual_group: individual_group_schema } } }

        run_test!
      end

      response '404', 'individual group not found' do
        let(:id) { 0 }

        run_test!
      end

      unauthorized_response { let(:id) { individual_group.id } }
      configuration_forbidden_response { let(:id) { individual_group.id } }
    end

    patch 'Rename an individual group' do
      tags 'Configuration Catalogs'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Changes the name of a group per language. Kind and visibility stay as they " \
                  "are.#{ApiAccessRequirements::CONFIGURATION_REQUIRED}"
      parameter name: :body, in: :body, required: true, schema: {
        type: :object,
        properties: {
          individual_group: {
            type: :object,
            properties: { translations: name_translations_input },
            required: ['translations']
          }
        },
        required: ['individual_group']
      }

      response '200', 'individual group renamed' do
        let(:id) { individual_group.id }
        let(:body) do
          {
            individual_group: {
              kind: 'soft',
              translations: { de: { name: 'Jugendparlament' }, en: { name: 'Youth parliament' } }
            }
          }
        end

        schema type: :object,
               properties: { data: { type: :object, properties: { individual_group: individual_group_schema } } }

        run_test! do
          individual_group.reload
          translation_audit = Audit.where(auditable: individual_group.translations.find_by(locale: :de)).last

          expect(individual_group.kind).to eq('hard')
          expect(individual_group.translations.find_by(locale: :en).name).to eq('Youth parliament')
          expect_audited_by_client(translation_audit)
        end
      end

      response '422', 'name cleared' do
        let(:id) { individual_group.id }
        let(:body) { { individual_group: { translations: { de: { name: '' } } } } }

        schema '$ref' => '#/components/schemas/ConfigurationValidationError'

        run_test!
      end

      response '404', 'individual group not found' do
        let(:id) { 0 }
        let(:body) { { individual_group: { translations: { de: { name: 'Gruppe' } } } } }

        run_test!
      end

      unauthorized_response { let(:id) { individual_group.id } }
      configuration_forbidden_response { let(:id) { individual_group.id } }
    end
  end
end
