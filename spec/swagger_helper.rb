# frozen_string_literal: true

require 'rails_helper'
require_relative 'schemas/projekts_schemas'
require_relative 'schemas/ideas_schemas'
require_relative 'schemas/comments_proposals_schemas'
require_relative 'schemas/budgets_schemas'
require_relative 'schemas/questions_formulars_schemas'
require_relative 'schemas/deficiency_reports_schemas'
require_relative 'schemas/milestones_livestreams_schemas'
require_relative 'schemas/point_of_interest_schemas'
require_relative 'schemas/miscellaneous_schemas'

Rswag::Specs::SwaggerRoot = Rails.root.join('public').to_s

RSpec.configure do |config|
  # Specify a root folder where Swagger JSON files are generated
  # NOTE: If you're using the rswag-api to serve API descriptions, you'll need
  # to ensure that it's configured to serve Swagger from the same folder
  config.openapi_root = Rails.root.join('swagger').to_s

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
        version: 'v1'
      },
      paths: {},
      # servers: [
      #   {
      #     url: Rails.application.secrets.swagger_host_url,
      #   }
      # ],
      tags: [
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
        { name: 'Iframes', description: 'Embedded iframe content' }
      ],
      'x-tagGroups': [
        {
          name: 'Projekts',
          tags: [
            'Projekts',
            'Projekt Phases',
            'Proposals',
            'Polls',
            'Milestones',
            'Budgets',
            'Budget Investments',
            'Comments',
            'Events',
            'Arguments',
            'Livestreams',
            'Notifications',
            'Questions',
            'Formulars',
            'Texts',
            'Iframes',
            'Point Of Interest Categories',
            'Point Of Interest Pins'
          ]
        },
        {
          name: 'Ideas',
          tags: ['Ideas']
        },
        {
          name: 'Deficiency Reports',
          tags: ['Deficiency Reports']
        }
      ],
      components: {
        securitySchemes: {
          bearer_auth: {
            type: :http,
            scheme: :bearer,
            bearerFormat: 'JWT'
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
      }
    }
  }

  # Specify the format of the output Swagger file when running 'rswag:specs:swaggerize'.
  # The openapi_specs configuration option has the filename including format in
  # the key, this may want to be changed to avoid putting yaml in json files.
  # Defaults to json. Accepts ':json' and ':yaml'.
  config.openapi_format = :yaml
end
