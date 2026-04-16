# frozen_string_literal: true

module Schemas
  module MilestonesLivestreams
    MILESTONE_SCHEMA = {
      type: :object,
      properties: {
        id: { type: :integer, description: 'Unique identifier for the milestone', example: 1 },
        title: { type: :string, description: 'The title or name of the milestone', example: 'Phase 1 Completion' },
        description: { type: :string, nullable: true, description: 'Description of what this milestone represents', example: 'Completion of initial consultation phase' },
        projekt_phase_id: { type: :integer, description: 'ID of the projekt phase this milestone belongs to', example: 15 },
        starts_at: { type: :string, format: :date_time, nullable: true, description: 'When the milestone period starts', example: '2024-01-15T00:00:00Z' },
        ends_at: { type: :string, format: :date_time, nullable: true, description: 'When the milestone period ends', example: '2024-02-15T23:59:59Z' },
        created_at: { type: :string, format: :date_time, description: 'Timestamp when the milestone was created', example: '2024-01-10T10:00:00Z' },
        updated_at: { type: :string, format: :date_time, description: 'Timestamp when the milestone was last modified', example: '2024-01-12T15:00:00Z' },
        milestone_statuses: {
          type: :array,
          description: 'Status updates associated with this milestone',
          items: { '$ref' => '#/components/schemas/MilestoneStatus' }
        }
      },
      required: %w[id title projekt_phase_id created_at updated_at]
    }.freeze

    MILESTONE_STATUS_SCHEMA = {
      type: :object,
      properties: {
        id: { type: :integer, description: 'Unique identifier for the milestone status', example: 1 },
        title: { type: :string, description: 'The title of the status update', example: 'Consultation Completed' },
        description: { type: :string, nullable: true, description: 'Details about this status update', example: 'We have gathered 500+ community responses' },
        milestone_id: { type: :integer, description: 'ID of the milestone this status belongs to', example: 3 },
        position: { type: :integer, description: 'Display order of status updates (lower numbers first)', example: 0 },
        created_at: { type: :string, format: :date_time, description: 'Timestamp when the status was created', example: '2024-01-20T12:00:00Z' },
        updated_at: { type: :string, format: :date_time, description: 'Timestamp when the status was last modified', example: '2024-01-20T12:00:00Z' }
      },
      required: %w[id title milestone_id position created_at updated_at]
    }.freeze

    LIVESTREAM_SCHEMA = {
      type: :object,
      properties: {
        id: { type: :integer, description: 'Unique identifier for the livestream', example: 1 },
        title: { type: :string, description: 'The title or name of the livestream event', example: 'Community Town Hall Discussion' },
        description: { type: :string, nullable: true, description: 'Description of the livestream content and agenda', example: 'Live discussion with city officials on budget priorities' },
        project_phase_id: { type: :integer, nullable: true, description: 'ID of the projekt phase this livestream belongs to', example: 20 },
        url: { type: :string, nullable: true, description: 'The URL where the livestream will be broadcast', example: 'https://youtube.com/live/ABC123' },
        scheduled_at: { type: :string, format: :date_time, nullable: true, description: 'When the livestream is scheduled to start', example: '2024-02-01T18:00:00Z' },
        created_at: { type: :string, format: :date_time, description: 'Timestamp when the livestream was created', example: '2024-01-25T09:00:00Z' },
        updated_at: { type: :string, format: :date_time, description: 'Timestamp when the livestream was last modified', example: '2024-01-28T14:30:00Z' }
      },
      required: %w[id title created_at updated_at]
    }.freeze

    def self.all
      {
        Milestone: MILESTONE_SCHEMA,
        MilestoneStatus: MILESTONE_STATUS_SCHEMA,
        Livestream: LIVESTREAM_SCHEMA
      }
    end
  end
end
