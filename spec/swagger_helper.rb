# frozen_string_literal: true

require 'rails_helper'
require_relative 'shared/api_client_helper'
require_relative 'shared/api_access_requirements'
require_relative 'shared/api_response_examples'
require_relative 'schemas/projekts_schemas'
require_relative 'schemas/ideas_schemas'
require_relative 'schemas/comments_proposals_schemas'
require_relative 'schemas/budgets_schemas'
require_relative 'schemas/questions_formulars_schemas'
require_relative 'schemas/deficiency_reports_schemas'
require_relative 'schemas/milestones_livestreams_schemas'
require_relative 'schemas/point_of_interest_schemas'
require_relative 'schemas/miscellaneous_schemas'
require_relative 'schemas/polls_schemas'

Rswag::Specs::SwaggerRoot = Rails.root.join('public').to_s

def read_api_doc(relative_path)
  content = File.read(Rails.root.join(relative_path))
  lines = content.lines

  min_indent = lines
    .reject { |line| line.strip.empty? }
    .map { |line| line.match(/^(\s*)/)[1].length }
    .min || 0

  lines
    .map { |line| line.chomp }
    .map { |line| line.strip.empty? ? "" : line.sub(/^\s{#{min_indent}}/, '') }
    .join("\n")
    .split("\n")
    .drop_while { |line| line.empty? }
    .reverse
    .drop_while { |line| line.empty? }
    .reverse
    .join("\n")
end

API_DESCRIPTION = [
  read_api_doc('doc/api/api_description.md'),
  read_api_doc('doc/api/api_changelog.md')
].join("\n\n")

RSpec.configure do |config|
  # Specify a root folder where Swagger JSON files are generated
  # NOTE: If you're using the rswag-api to serve API descriptions, you'll need
  # to ensure that it's configured to serve Swagger from the same folder
  config.openapi_root = Rails.root.join('public', 'api_docs').to_s

  # Define one or more Swagger documents and provide global metadata for each one
  # When you run the 'rswag:specs:swaggerize' rake task, the complete Swagger will
  # be generated at the provided relative path under openapi_root
  # By default, the operations defined in spec files are added to the first
  # document below. You can override this behavior by adding a openapi_spec tag to the
  # the root example_group in your specs, e.g. describe '...', openapi_spec: 'v2/swagger.json'
  config.openapi_specs = {
    'v1/swagger.yaml' => {
      openapi: '3.0.1',
      info: {
        title: 'API V1',
        version: 'v1',
        description: API_DESCRIPTION
      },
      paths: {},
      # servers: [
      #   {
      #     url: Rails.application.secrets.swagger_host_url,
      #   }
      # ],
      tags: [
        { name: 'Auth', description: 'Authentication and token management' },
        { name: 'Projekts', description: 'Projekt management and core operations' },
        { name: 'Projekt Phases', description: 'Phases within projekts' },
        { name: 'Proposals', description: 'Proposals for projekt phases' },
        { name: 'Comments', description: 'Comments on projekt phases' },
        { name: 'Polls', description: 'Polls within projekt phases' },
        { name: 'Milestones', description: 'Milestones for projekt phases' },
        { name: 'Budgets', description: 'Budget management for projekt phases' },
        { name: 'Budget Investments', description: 'Budget investment management' },
        { name: 'Arguments', description: 'Arguments for projekt phases' },
        { name: 'Events', description: 'Events associated with projekts' },
        { name: 'Livestreams', description: 'Livestream functionality for projekts' },
        { name: 'Notifications', description: 'Notifications for projekt updates' },
        { name: 'Point Of Interest Categories', description: 'Categories for points of interest in projekts' },
        { name: 'Point Of Interest Pins', description: 'Location pins for projekts' },
        { name: 'Questions', description: 'Questions related to projekt phases' },
        { name: 'Formulars', description: 'Forms associated with projekt phases' },
        { name: 'Texts', description: 'Text content for projekt phases' },
        { name: 'Ideas', description: 'Citizen ideas and proposals' },
        { name: 'Deficiency Reports', description: 'Reports of deficiencies or issues' },
        { name: 'Iframes', description: 'Embedded iframe content' },
        { name: 'Poll Questions', description: 'Questions within polls' },
        { name: 'Poll Question Answers', description: 'Answer options for poll questions' },
        { name: 'Question Options', description: 'Answer options for projekt phase questions' },
        { name: 'Budget Phases', description: 'Workflow phases and timeline for budgets' },
        { name: 'Milestone Statuses', description: 'Status definitions for milestones' },
        { name: 'Progress Bars', description: 'Progress indicators for projekt phases' },
        { name: 'Idea Categories', description: 'Categories for citizen ideas' },
        { name: 'Idea Officers', description: 'Officers responsible for citizen ideas' },
        { name: 'Deficiency Report Categories', description: 'Categories for deficiency reports' },
        { name: 'Masterportal', description: 'Masterportal GIS integration endpoints' },
        { name: 'Error Handling', description: 'Responses for unknown or unsupported API routes' }
      ],
      'x-tagGroups': [
        {
          name: 'Auth',
          tags: ['Auth']
        },
        {
          name: 'Projekts',
          tags: [
            'Projekts',
            'Projekt Phases',
            'Proposals',
            'Polls',
            'Milestones',
            'Milestone Statuses',
            'Budgets',
            'Budget Investments',
            'Budget Phases',
            'Comments',
            'Events',
            'Arguments',
            'Livestreams',
            'Notifications',
            'Questions',
            'Question Options',
            'Formulars',
            'Progress Bars',
            'Texts',
            'Iframes',
            'Point Of Interest Categories',
            'Point Of Interest Pins',
            'Poll Questions',
            'Poll Question Answers'
          ]
        },
        {
          name: 'Ideas',
          tags: ['Ideas', 'Idea Categories', 'Idea Officers']
        },
        {
          name: 'Deficiency Reports',
          tags: ['Deficiency Reports', 'Deficiency Report Categories']
        },
        {
          name: 'Integrations',
          tags: ['Masterportal']
        },
        {
          name: 'General',
          tags: ['Error Handling']
        }
      ],
      components: {
        securitySchemes: {
          bearer_auth: {
            type: :http,
            scheme: :bearer,
            bearerFormat: 'Auth Token'
          },
          masterportal_sync_auth: {
            type: :http,
            scheme: :bearer,
            bearerFormat: 'Masterportal Sync Token'
          }
        },
        schemas: Schemas::Projekts.all
                         .merge(Schemas::Ideas.all)
                         .merge(Schemas::CommentsProposals.all)
                         .merge(Schemas::Budgets.all)
                         .merge(Schemas::QuestionsFormulars.all)
                         .merge(Schemas::DeficiencyReports.all)
                         .merge(Schemas::MilestonesLivestreams.all)
                         .merge(Schemas::PointOfInterest.all)
                         .merge(Schemas::Miscellaneous.all)
                         .merge(Schemas::Polls.all)
      }
    }
  }

  # Specify the format of the output Swagger file when running 'rswag:specs:swaggerize'.
  # The openapi_specs configuration option has the filename including format in
  # the key, this may want to be changed to avoid putting yaml in json files.
  # Defaults to json. Accepts ':json' and ':yaml'.
  config.openapi_format = :yaml

  config.include ApiClientHelper, type: :request
  config.extend ApiResponseExamples, type: :request
end
