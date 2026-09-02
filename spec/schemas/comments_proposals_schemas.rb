# frozen_string_literal: true

module Schemas
  module CommentsProposals
    COMMENT_SCHEMA = {
      type: :object,
      properties: {
        id: { type: :integer, description: 'Unique identifier for the comment', example: 1 },
        body: { type: :string, description: 'The text content of the comment', example: 'This is a helpful comment on the proposal.' },
        user_id: { type: :integer, nullable: true, description: 'ID of the user who posted the comment', example: 15 },
        created_at: { type: :string, format: :date_time, description: 'Timestamp when the comment was created', example: '2024-01-20T09:15:00Z' },
        updated_at: { type: :string, format: :date_time, description: 'Timestamp when the comment was last modified', example: '2024-01-20T10:30:00Z' },
        parent_id: { type: :integer, nullable: true, description: 'ID of the parent comment if this is a reply. Null for root comments.', example: 5 },
        ancestry: { type: :string, nullable: true, description: 'Ancestry path for nested comment hierarchy (auto-maintained)', example: '5/42' },
        commentable_type: { type: :string, description: 'The type of resource being commented on (e.g., ProjektPhase, Proposal)', example: 'ProjektPhase' },
        commentable_id: { type: :integer, description: 'The ID of the resource being commented on', example: 10 }
      },
      required: %w[id body created_at updated_at commentable_type commentable_id]
    }.freeze

    PROPOSAL_SCHEMA = {
      type: :object,
      properties: {
        id: { type: :integer, description: 'Unique identifier for the proposal', example: 1 },
        title: { type: :string, description: 'The title of the proposal', example: 'Green Energy Initiative' },
        description: { type: :string, nullable: true, description: 'Detailed description of the proposal and its goals', example: 'Implement renewable energy across public buildings' },
        author_id: { type: :integer, nullable: true, description: 'ID of the user who created the proposal', example: 20 },
        created_at: { type: :string, format: :date_time, description: 'Timestamp when the proposal was created', example: '2024-01-15T12:00:00Z' },
        updated_at: { type: :string, format: :date_time, description: 'Timestamp when the proposal was last modified', example: '2024-01-18T15:45:00Z' },
        projekt_phase_id: { type: :integer, nullable: true, description: 'ID of the projekt phase this proposal belongs to', example: 25 },
        status: { type: :string, nullable: true, description: 'Current status of the proposal (e.g., published, archived)', example: 'published' },
        comments_count: { type: :integer, nullable: true, description: 'Total number of comments on the proposal', example: 12 },
        image: { '$ref' => '#/components/schemas/ImageResponse' }
      },
      required: %w[id created_at updated_at]
    }.freeze

    MAP_LOCATION_ATTRIBUTES_CREATE = {
      type: :object,
      nullable: true,
      description: 'Geographic location data for mapping the proposal',
      properties: {
        id: { type: :integer, nullable: true },
        latitude: { type: :number, description: 'Latitude coordinate' },
        longitude: { type: :number, description: 'Longitude coordinate' },
        altitude: { type: :number, nullable: true },
        zoom: { type: :integer, nullable: true },
        features: { type: :string, nullable: true },
        rendering_library: { type: :string, nullable: true },
        show_admin_shape: { type: :boolean, nullable: true },
        _destroy: { type: :boolean, nullable: true }
      },
      required: %w[latitude longitude]
    }.freeze

    MAP_LOCATION_ATTRIBUTES_UPDATE = {
      type: :object,
      nullable: true,
      description: 'Geographic location data for mapping the proposal',
      properties: {
        id: { type: :integer, nullable: true },
        latitude: { type: :number, nullable: true, description: 'Latitude coordinate' },
        longitude: { type: :number, nullable: true, description: 'Longitude coordinate' },
        altitude: { type: :number, nullable: true },
        zoom: { type: :integer, nullable: true },
        features: { type: :string, nullable: true },
        rendering_library: { type: :string, nullable: true },
        show_admin_shape: { type: :boolean, nullable: true },
        _destroy: { type: :boolean, nullable: true }
      }
    }.freeze

    IMAGE_ATTRIBUTES_CREATE = {
      type: :object,
      nullable: true,
      description: 'Optional: Image to illustrate the proposal. Upload as base64-encoded data.',
      properties: {
        id: { type: :integer, nullable: true },
        title: { type: :string, nullable: true, description: 'Image caption or alt text' },
        attachment: { type: :string, nullable: true, description: 'Base64-encoded image file. Supported formats: JPEG, PNG, GIF, WebP' },
        cached_attachment: { type: :string, nullable: true },
        credits: { type: :string, nullable: true, description: 'Image source attribution' },
        ai_generated: { type: :boolean, nullable: true, description: 'Set to true when the image was created or edited with AI; the public page then shows the AI disclosure label' },
        user_id: { type: :integer, nullable: true },
        _destroy: { type: :boolean, nullable: true, description: 'Set to true to remove the current image' }
      }
    }.freeze

    IMAGE_ATTRIBUTES_UPDATE = {
      type: :object,
      nullable: true,
      description: 'Update, replace, or remove the proposal image. Attach a new image (base64-encoded), update metadata (title/credits), or set _destroy=true to remove.',
      properties: {
        id: { type: :integer, nullable: true },
        title: { type: :string, nullable: true, description: 'Image caption or alt text' },
        attachment: { type: :string, nullable: true, description: 'Base64-encoded image file. Supported formats: JPEG, PNG, GIF, WebP' },
        cached_attachment: { type: :string, nullable: true },
        credits: { type: :string, nullable: true, description: 'Image source attribution' },
        ai_generated: { type: :boolean, nullable: true, description: 'Set to true when the image was created or edited with AI; the public page then shows the AI disclosure label' },
        user_id: { type: :integer, nullable: true },
        _destroy: { type: :boolean, nullable: true, description: 'Set to true to remove the current image' }
      }
    }.freeze

    DOCUMENTS_ATTRIBUTES = {
      type: :array,
      nullable: true,
      description: 'Array of document attachments',
      items: {
        type: :object,
        properties: {
          id: { type: :integer, nullable: true },
          title: { type: :string, nullable: true },
          attachment: { type: :string, nullable: true },
          cached_attachment: { type: :string, nullable: true },
          user_id: { type: :integer, nullable: true },
          _destroy: { type: :boolean, nullable: true }
        }
      }
    }.freeze

    TRANSLATIONS_ATTRIBUTES_CREATE = {
      type: :array,
      description: 'Multilingual content. Provide title and description for each language.',
      items: {
        type: :object,
        properties: {
          id: { type: :integer, nullable: true },
          locale: { type: :string, description: 'Language code (e.g., en, de, es)' },
          title: { type: :string, description: 'Proposal title in the specified language' },
          description: { type: :string, description: 'Proposal description in the specified language' },
          summary: { type: :string, nullable: true, description: 'Brief summary in the specified language' },
          retired_explanation: { type: :string, nullable: true, description: 'Explanation for retirement in the specified language' },
          _destroy: { type: :boolean, nullable: true }
        }
      }
    }.freeze

    TRANSLATIONS_ATTRIBUTES_UPDATE = {
      type: :array,
      nullable: true,
      description: 'Update multilingual content',
      items: {
        type: :object,
        properties: {
          id: { type: :integer, nullable: true },
          locale: { type: :string, description: 'Language code' },
          title: { type: :string, nullable: true, description: 'Localized proposal title' },
          description: { type: :string, nullable: true, description: 'Localized proposal description' },
          summary: { type: :string, nullable: true, description: 'Brief summary in the specified language' },
          retired_explanation: { type: :string, nullable: true, description: 'Explanation for retirement in the specified language' },
          _destroy: { type: :boolean, nullable: true }
        }
      }
    }.freeze

    PROPOSAL_PARAMS_BASE = {
      responsible_name: { type: :string, description: 'Name of the person or organization responsible for the proposal' },
      video_url: { type: :string, nullable: true, description: 'URL to a video explaining the proposal (YouTube, Vimeo, etc.)' },
      geozone_id: { type: :integer, description: 'ID of the geographic zone where the proposal applies' },
      selected: { type: :boolean, nullable: true, description: 'Admin-only: Whether this proposal is selected' },
      on_behalf_of: { type: :string, nullable: true, description: 'Name of the organization or group submitting on behalf of' },
      sentiment_id: { type: :integer, nullable: true, description: 'ID of the sentiment classification for this proposal' },
      official_answer: { type: :string, nullable: true, description: 'Official response or answer from administrators' },
      admin_accepted: { type: :boolean, nullable: true, description: 'Admin-only: Whether the proposal has been accepted by administrators' },
      tag_list: { type: :string, nullable: true, description: 'Comma-separated list of tags for categorization' },
      related_sdg_list: { type: :string, nullable: true, description: 'Comma-separated list of related Sustainable Development Goals' },
      resource_terms: { type: :boolean, description: 'Acceptance of resource terms (required for creation)' },
      projekt_label_ids: {
        type: :array,
        items: { type: :integer },
        nullable: true,
        description: 'Array of projekt label IDs to associate with this proposal'
      }
    }.freeze

    PROPOSAL_CREATE_PARAMS = {
      type: :object,
      properties: {
        proposal: {
          type: :object,
          properties: PROPOSAL_PARAMS_BASE.merge(
            published: { type: :boolean, nullable: true, description: 'Whether to publish the proposal immediately on creation, making it visible in the frontend. Defaults to true. Set to false to create the proposal as a draft and publish it later via PATCH /api/proposals/{id}/publish.' },
            map_location_attributes: MAP_LOCATION_ATTRIBUTES_CREATE,
            image_attributes: IMAGE_ATTRIBUTES_CREATE,
            documents_attributes: DOCUMENTS_ATTRIBUTES,
            translations_attributes: TRANSLATIONS_ATTRIBUTES_CREATE
          ),
          required: %w[title description responsible_name geozone_id resource_terms]
        }
      },
      required: ['proposal']
    }.freeze

    PROPOSAL_UPDATE_PARAMS = {
      type: :object,
      properties: {
        proposal: {
          type: :object,
          properties: PROPOSAL_PARAMS_BASE.merge(
            responsible_name: { type: :string, nullable: true, description: 'Name of the person or organization responsible for the proposal' },
            geozone_id: { type: :integer, nullable: true, description: 'ID of the geographic zone where the proposal applies' },
            resource_terms: { type: :boolean, nullable: true, description: 'Acceptance of resource terms' },
            map_location_attributes: MAP_LOCATION_ATTRIBUTES_UPDATE,
            image_attributes: IMAGE_ATTRIBUTES_UPDATE,
            documents_attributes: DOCUMENTS_ATTRIBUTES,
            translations_attributes: TRANSLATIONS_ATTRIBUTES_UPDATE
          )
        }
      }
    }.freeze

    def self.all
      {
        Comment: COMMENT_SCHEMA,
        Proposal: PROPOSAL_SCHEMA
      }
    end
  end
end
