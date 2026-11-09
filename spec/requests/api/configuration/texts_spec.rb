# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Configuration Texts API', type: :request, openapi_spec: 'v1/swagger.yaml' do
  let!(:api_client) { create_configuration_api_client }
  let(:Authorization) { "Bearer #{api_client.access_token}" }
  let(:text_key) { 'debates.index.section_footer.title' }

  text_locale_schema = {
    type: :object,
    properties: {
      value: { type: :string, nullable: true, description: 'Text set for this instance; null when the bundled text is used' },
      default: { type: :string, nullable: true, description: 'Bundled text of the platform' }
    }
  }

  text_schema = {
    type: :object,
    properties: {
      key: { type: :string, example: 'debates.index.section_footer.title' },
      translations: {
        type: :object,
        description: 'Per language (`de`, `en`, …)',
        additionalProperties: text_locale_schema
      }
    },
    required: %w[key translations]
  }

  email_template_schema = {
    type: :object,
    properties: {
      key: { type: :string, example: 'mailer.comment', description: '`<mailer class in snake case>.<mailer action>`' },
      mailer_class: { type: :string, example: 'Mailer' },
      mailer_action: { type: :string, example: 'comment' },
      section: { type: :string, enum: %w[global deficiency_reports] },
      variables: {
        type: :array,
        items: { type: :string },
        description: 'Liquid variables available in subject and body, e.g. `{{ recipient_greeting }}`'
      },
      translations: {
        type: :object,
        description: 'Per language; a language without a subject or body sends the built-in email',
        additionalProperties: {
          type: :object,
          properties: {
            subject: { type: :string, nullable: true },
            body: { type: :string, nullable: true },
            updated_at: { type: :string, format: :date_time, nullable: true }
          }
        }
      }
    },
    required: %w[key mailer_class mailer_action section variables translations]
  }

  path '/api/configuration/texts' do
    get 'List interface texts' do
      tags 'Configuration Texts'
      produces 'application/json'
      security [bearer_auth: []]
      description "Interface texts of the editable sections, with the instance's own text and the " \
                  "bundled default per language. Filter by key prefix; the list is paginated." \
                  "#{ApiAccessRequirements::CONFIGURATION_REQUIRED}"
      parameter name: :prefix, in: :query, type: :string, required: false,
                description: 'Only keys starting with this prefix, e.g. `debates.index`'
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number (**default:** 1)'
      parameter name: :per_page, in: :query, type: :integer, required: false,
                description: 'Texts per page (**default:** 100, max: 2000)'

      response '200', 'texts listed' do
        let(:prefix) { 'debates.index.section_footer' }

        before do
          content = I18nContent.create!(key: 'debates.index.section_footer.title')
          Globalize.with_locale(:de) { content.update!(value: 'Eigene Hilfe') }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: { texts: { type: :array, items: text_schema } },
                   required: ['texts']
                 },
                 pagination: Schemas::Miscellaneous::PAGINATION_RESPONSE_SCHEMA
               },
               required: %w[data pagination]

        run_test! do |response|
          texts = JSON.parse(response.body)['data']['texts']
          title = texts.find { |text| text['key'] == 'debates.index.section_footer.title' }

          expect(texts.map { |text| text['key'] }).to all(start_with('debates.index.section_footer'))
          expect(title['translations']['de']).to eq('value' => 'Eigene Hilfe', 'default' => 'Hilfe zu Diskussionen')
          expect(title['translations']['en']['value']).to be_nil
        end
      end

      response '200', 'texts paginated' do
        let(:per_page) { 2 }

        run_test! do |response|
          body = JSON.parse(response.body)

          expect(body['data']['texts'].size).to eq(2)
          expect(body['pagination']['total_count']).to be > 2
        end
      end

      unauthorized_response
      configuration_forbidden_response
    end

    patch 'Change interface texts' do
      tags 'Configuration Texts'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Sets the instance's own text per key and language. An empty value or `null` " \
                  "brings back the bundled default. Every key must be listed by `GET` and every " \
                  "language supported, otherwise nothing is changed. Texts written here are not " \
                  "overwritten by machine translation.#{ApiAccessRequirements::CONFIGURATION_REQUIRED}"
      parameter name: :body, in: :body, required: true, schema: {
        type: :object,
        properties: {
          texts: {
            type: :object,
            description: 'Text key → { language → text }',
            additionalProperties: {
              type: :object,
              additionalProperties: { type: :string, nullable: true, maxLength: 5000 }
            },
            example: { 'debates.index.section_footer.title' => { 'de' => 'Hilfe', 'en' => 'Help' } }
          }
        },
        required: ['texts']
      }

      response '200', 'texts changed' do
        let(:body) { { texts: { text_key => { 'de' => 'Neue Hilfe', 'en' => 'New help' } } } }

        schema type: :object,
               properties: {
                 data: { type: :object, properties: { texts: { type: :array, items: text_schema } } }
               }

        run_test! do |response|
          text = JSON.parse(response.body)['data']['texts'].first
          content = I18nContent.find_by(key: text_key)
          audit = Audit.where(associated: content).last

          expect(text['translations']['de']['value']).to eq('Neue Hilfe')
          expect(text['translations']['en']['value']).to eq('New help')
          expect(I18n.t(text_key, locale: :de)).to eq('Neue Hilfe')
          expect(audit.comment).to eq("api_client:#{api_client.id}")
          expect(audit.user).to eq(api_client.content_author)
        end
      end

      response '200', 'empty value brings back the bundled text' do
        before do
          content = I18nContent.create!(key: 'debates.index.section_footer.title')
          Globalize.with_locale(:de) { content.update!(value: 'Eigene Hilfe') }
        end

        let(:body) { { texts: { text_key => { 'de' => '' } } } }

        run_test! do |response|
          text = JSON.parse(response.body)['data']['texts'].first

          expect(text['translations']['de']['value']).to be_nil
          expect(I18n.t(text_key, locale: :de)).to eq('Hilfe zu Diskussionen')
        end
      end

      response '200', 'texts of keys ending in _html are cleaned of script' do
        let(:body) do
          {
            texts: {
              'custom.layouts.header.title_html' => { 'de' => '<strong>Mitmachen</strong><script>alert(1)</script>' }
            }
          }
        end

        run_test! do
          content = I18nContent.find_by!(key: 'custom.layouts.header.title_html')
          stored_value = Globalize.with_locale(:de) { content.value }

          expect(stored_value).to include('<strong>Mitmachen</strong>')
          expect(stored_value).not_to include('<script')
        end
      end

      response '422', 'unknown key, admin text or unsupported language - nothing is changed' do
        let(:body) do
          {
            texts: {
              text_key => { 'de' => 'Neue Hilfe' },
              'admin.dashboard.index.title' => { 'de' => 'Admin' },
              'machine_setting.org_name' => { 'de' => 'Stadt' },
              'debates.index.section_footer.description' => { 'xx' => 'Unbekannt' }
            }
          }
        end

        schema '$ref' => '#/components/schemas/ConfigurationValidationError'

        run_test! do |response|
          details = JSON.parse(response.body)['error']['details']

          expect(details.keys).to match_array(
            %w[admin.dashboard.index.title machine_setting.org_name debates.index.section_footer.description]
          )
          expect(I18nContent.find_by(key: text_key)).to be_nil
        end
      end

      response '400', 'texts object missing' do
        let(:body) { { texts: 'Hilfe' } }

        schema ApiResponseExamples::ERROR_SCHEMA

        run_test!
      end

      unauthorized_response
      configuration_forbidden_response
    end
  end

  path '/api/configuration/email_templates' do
    get 'List email templates' do
      tags 'Configuration Texts'
      produces 'application/json'
      security [bearer_auth: []]
      description "The email templates that belong to no projekt phase (global and deficiency " \
                  "report emails), with their Liquid variables and the subject and body per " \
                  "language.#{ApiAccessRequirements::CONFIGURATION_REQUIRED}"

      response '200', 'email templates listed' do
        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: { email_templates: { type: :array, items: email_template_schema } },
                   required: ['email_templates']
                 }
               }

        run_test! do |response|
          keys = JSON.parse(response.body)['data']['email_templates'].map { |template| template['key'] }

          expect(keys).to include('mailer.comment', 'deficiency_report_mailer.notify_officer')
          expect(keys.size).to eq(
            SiteCustomization::EmailTemplate::GLOBAL_EMAIL_TEMPLATES.size +
              SiteCustomization::EmailTemplate::DEFICIENCY_REPORT_EMAIL_TEMPLATES.size
          )
        end
      end

      unauthorized_response
      configuration_forbidden_response
    end
  end

  path '/api/configuration/email_templates/{key}' do
    parameter name: :key, in: :path, type: :string, required: true,
              description: '`<mailer class in snake case>.<mailer action>`, e.g. `mailer.comment`'

    get 'Show an email template' do
      tags 'Configuration Texts'
      produces 'application/json'
      security [bearer_auth: []]
      description "One email template with its subject and body per language.#{ApiAccessRequirements::CONFIGURATION_REQUIRED}"

      response '200', 'email template found' do
        let(:key) { 'mailer.comment' }

        schema type: :object, properties: { data: { type: :object, properties: { email_template: email_template_schema } } }

        run_test! do |response|
          template = JSON.parse(response.body)['data']['email_template']

          expect(template['variables']).to include('recipient_greeting', 'comment_body')
        end
      end

      response '404', 'unknown or projekt phase template' do
        let(:key) { 'mailer.budget_investment_created' }

        run_test!
      end

      unauthorized_response { let(:key) { 'mailer.comment' } }
      configuration_forbidden_response { let(:key) { 'mailer.comment' } }
    end

    patch 'Change an email template' do
      tags 'Configuration Texts'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Sets subject and body per language. Both are Liquid templates and may use the " \
                  "template's variables; an empty value brings back the built-in text. Only the " \
                  "languages and attributes sent are changed.#{ApiAccessRequirements::CONFIGURATION_REQUIRED}"
      parameter name: :body, in: :body, required: true, schema: {
        type: :object,
        properties: {
          email_template: {
            type: :object,
            properties: {
              translations: {
                type: :object,
                additionalProperties: {
                  type: :object,
                  properties: {
                    subject: { type: :string, nullable: true, maxLength: 255 },
                    body: { type: :string, nullable: true, maxLength: 10_000 }
                  }
                },
                example: { 'de' => { 'subject' => 'Neuer Kommentar', 'body' => '<p>{{ recipient_greeting }}</p>' } }
              }
            },
            required: ['translations']
          }
        },
        required: ['email_template']
      }

      response '200', 'email template changed' do
        let(:key) { 'mailer.comment' }
        let(:body) do
          {
            email_template: {
              translations: {
                de: { subject: 'Neuer Kommentar', body: '<p>{{ recipient_greeting }}</p>' },
                en: { subject: 'New comment' }
              }
            }
          }
        end

        schema type: :object, properties: { data: { type: :object, properties: { email_template: email_template_schema } } }

        run_test! do |response|
          translations = JSON.parse(response.body)['data']['email_template']['translations']
          template = SiteCustomization::EmailTemplate.find_by(
            projekt_phase_id: nil, mailer_class: 'Mailer', mailer_action: 'comment', locale: 'de'
          )

          expect(translations['de']).to include('subject' => 'Neuer Kommentar', 'body' => '<p>{{ recipient_greeting }}</p>')
          expect(translations['en']).to include('subject' => 'New comment', 'body' => nil)
          expect(template.audits.last.comment).to eq("api_client:#{api_client.id}")
          expect(template.audits.last.user).to eq(api_client.content_author)
        end
      end

      response '422', 'invalid Liquid template or unsupported language' do
        let(:key) { 'mailer.comment' }
        let(:body) do
          { email_template: { translations: { de: { body: '{% if recipient_greeting %}Hallo' }, xx: { subject: 'Hi' } } } }
        end

        schema '$ref' => '#/components/schemas/ConfigurationValidationError'

        run_test! do
          expect(SiteCustomization::EmailTemplate.where(mailer_action: 'comment', projekt_phase_id: nil)).to be_empty
        end
      end

      response '422', 'invalid Liquid template' do
        let(:key) { 'mailer.comment' }
        let(:body) { { email_template: { translations: { de: { body: '{% if recipient_greeting %}Hallo' } } } } }

        schema '$ref' => '#/components/schemas/ConfigurationValidationError'

        run_test! do |response|
          expect(JSON.parse(response.body)['error']['details'].keys).to eq(['de.body'])
        end
      end

      response '404', 'unknown template' do
        let(:key) { 'mailer.unknown_action' }
        let(:body) { { email_template: { translations: { de: { subject: 'Hi' } } } } }

        run_test!
      end

      unauthorized_response { let(:key) { 'mailer.comment' } }
      configuration_forbidden_response { let(:key) { 'mailer.comment' } }
    end
  end
end
