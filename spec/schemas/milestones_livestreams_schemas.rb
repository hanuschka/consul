# frozen_string_literal: true

module Schemas
  module MilestonesLivestreams
    MILESTONE_SCHEMA = {
      type: :object,
      properties: {
        id: { type: :integer, description: 'Unique identifier for the milestone', example: 1 },
        title: { type: :string, nullable: true, description: 'Title in the current language', example: 'Phase 1 Completion' },
        description: { type: :string, nullable: true, description: 'Description in the current language', example: 'Completion of initial consultation phase' },
        custom_date: { type: :string, nullable: true, description: 'Date text shown instead of the publication date, in the current language', example: 'Spring 2026' },
        publication_date: { type: :string, format: :date_time, description: 'Date the milestone is listed under', example: '2026-05-01T00:00:00Z' },
        translations: Schemas::Miscellaneous.translations_schema(%w[title description custom_date]),
        milestoneable_type: { type: :string, description: 'Type of the record the milestone belongs to', example: 'ProjektPhase' },
        milestoneable_id: { type: :integer, description: 'ID of the record the milestone belongs to', example: 15 },
        milestoneable: {
          type: :object,
          description: 'The record the milestone belongs to. Phases also carry their tab name and projekt id.',
          properties: {
            id: { type: :integer, example: 15 },
            type: { type: :string, example: 'ProjektPhase' },
            title: { type: :string, nullable: true, example: 'Meilensteine' },
            projekt_id: { type: :integer, nullable: true, example: 3 }
          },
          additionalProperties: false
        },
        projekt: {
          type: :object,
          description: 'Projekt of the phase the milestone belongs to',
          properties: {
            id: { type: :integer, example: 3 },
            title: { type: :string, nullable: true, example: 'Marktplatz' }
          },
          additionalProperties: false
        },
        status_id: { type: :integer, nullable: true, description: 'ID of the milestone status', example: 2 },
        status: {
          type: :object,
          nullable: true,
          description: 'Status of the milestone',
          properties: {
            id: { type: :integer, example: 2 },
            name: { type: :string, example: 'In progress' },
            description: { type: :string, nullable: true, example: 'Work has started' }
          },
          additionalProperties: false
        },
        image: { '$ref' => '#/components/schemas/ImageResponse' },
        documents: { type: :array, description: 'Documents attached to the milestone', items: { '$ref' => '#/components/schemas/Document' } },
        created_at: { type: :string, format: :date_time, description: 'Timestamp when the milestone was created', example: '2024-01-10T10:00:00Z' },
        updated_at: { type: :string, format: :date_time, description: 'Timestamp when the milestone was last modified', example: '2024-01-12T15:00:00Z' }
      },
      required: %w[id publication_date milestoneable_type milestoneable_id translations documents created_at updated_at],
      additionalProperties: false
    }.freeze

    MILESTONE_WRITE_PARAMS = {
      type: :object,
      properties: {
        milestone: {
          type: :object,
          properties: {
            title: { type: :string, description: 'Title in the current language (max 80 characters)' },
            description: { type: :string, description: 'Description in the current language. Required unless status_id is provided.' },
            custom_date: { type: :string, nullable: true, description: 'Date text shown instead of the publication date (optional)' },
            translations: Schemas::Miscellaneous.translations_schema(%w[title description custom_date]),
            publication_date: { type: :string, format: :date, description: 'Publication date in YYYY-MM-DD format. Required on create.' },
            status_id: { type: :integer, nullable: true, description: 'Milestone status ID (optional). When provided, description becomes optional.' },
            image_attributes: { '$ref' => '#/components/schemas/ImageAttributesApi' },
            documents_attributes: Schemas::CommentsProposals::DOCUMENTS_ATTRIBUTES
          }
        }
      },
      required: ['milestone']
    }.freeze

    MILESTONE_STATUS_SCHEMA = {
      type: :object,
      properties: {
        id: { type: :integer, description: 'Unique identifier for the milestone status', example: 1 },
        name: { type: :string, description: 'Name of the status', example: 'In progress' },
        description: { type: :string, nullable: true, description: 'What the status means', example: 'Work on this step has started' },
        milestones_count: { type: :integer, description: 'Number of milestones with this status', example: 4 },
        created_at: { type: :string, format: :date_time, description: 'Timestamp when the status was created', example: '2024-01-20T12:00:00Z' },
        updated_at: { type: :string, format: :date_time, description: 'Timestamp when the status was last modified', example: '2024-01-20T12:00:00Z' }
      },
      required: %w[id name created_at updated_at],
      additionalProperties: false
    }.freeze

    LIVESTREAM_SCHEMA = {
      type: :object,
      properties: {
        id: { type: :integer, description: 'Unique identifier for the livestream', example: 1 },
        title: { type: :string, nullable: true, description: 'The title or name of the livestream event', example: 'Community Town Hall Discussion' },
        description: { type: :string, nullable: true, description: 'Description of the livestream content and agenda', example: 'Live discussion with city officials on budget priorities' },
        projekt_phase_id: { type: :integer, nullable: true, description: 'ID of the projekt phase this livestream belongs to', example: 20 },
        url: { type: :string, nullable: true, description: 'The URL where the livestream will be broadcast', example: 'https://youtube.com/live/ABC123' },
        starts_at: { type: :string, format: :date_time, nullable: true, description: 'When the livestream starts', example: '2024-02-01T18:00:00Z' },
        video_platform: { type: :string, nullable: true, description: 'Platform of the stream, derived from the URL on save', example: 'youtube' },
        external_id: { type: :string, nullable: true, description: 'Video id on the platform, derived from the URL on save', example: 'ABC123' },
        preview_image_url: { type: :string, nullable: true, description: 'Preview image of the stream', example: 'https://img.youtube.com/vi/ABC123/hqdefault.jpg' },
        projekt_phase: { '$ref' => '#/components/schemas/ProjektPhaseReference' },
        projekt: { '$ref' => '#/components/schemas/ProjektReference' },
        questions: {
          type: :array,
          description: 'Questions asked during the livestream',
          items: { '$ref' => '#/components/schemas/Question' }
        },
        created_at: { type: :string, format: :date_time, description: 'Timestamp when the livestream was created', example: '2024-01-25T09:00:00Z' },
        updated_at: { type: :string, format: :date_time, description: 'Timestamp when the livestream was last modified', example: '2024-01-28T14:30:00Z' }
      },
      required: %w[id created_at updated_at],
      additionalProperties: false
    }.freeze

    def self.all
      {
        Milestone: MILESTONE_SCHEMA,
        MilestoneWriteParams: MILESTONE_WRITE_PARAMS,
        MilestoneStatus: MILESTONE_STATUS_SCHEMA,
        Livestream: LIVESTREAM_SCHEMA
      }
    end
  end
end
