# frozen_string_literal: true

module Schemas
  module CommentsProposals
    COMMENT_REFERENCE_SCHEMA = {
      type: :object,
      description: 'The comment this comment replies to',
      properties: {
        id: { type: :integer },
        body: { type: :string, nullable: true },
        user_id: { type: :integer, description: 'Only returned to admin clients.' },
        author: { '$ref' => '#/components/schemas/Author' },
        created_at: { type: :string, format: :date_time },
        updated_at: { type: :string, format: :date_time }
      },
      additionalProperties: false
    }.freeze

    COMMENT_SCHEMA = {
      type: :object,
      properties: {
        id: { type: :integer, description: 'Unique identifier for the comment', example: 1 },
        body: { type: :string, nullable: true, description: 'Text of the comment in the current language', example: 'This is a helpful comment on the proposal.' },
        translations: Schemas::Miscellaneous.translations_schema(%w[body]),
        user_id: { type: :integer, nullable: true, description: 'ID of the user who posted the comment. Only returned to admin clients.', example: 15 },
        internal: { type: :boolean, description: 'True for internal valuation comments, which are never shown publicly. Only returned to admin clients, the only clients that receive internal comments at all.', example: false },
        author: { '$ref' => '#/components/schemas/Author' },
        created_at: { type: :string, format: :date_time, description: 'Timestamp when the comment was created', example: '2024-01-20T09:15:00Z' },
        updated_at: { type: :string, format: :date_time, description: 'Timestamp when the comment was last modified', example: '2024-01-20T10:30:00Z' },
        ancestry: { type: :string, nullable: true, description: 'Ancestry path of the comment: the ids of its parent comments separated by slashes. Null for root comments.', example: '5/42' },
        cached_votes_up: { type: :integer, nullable: true, description: 'Number of upvotes', example: 3 },
        cached_votes_down: { type: :integer, nullable: true, description: 'Number of downvotes', example: 0 },
        cached_votes_score: { type: :integer, nullable: true, description: 'Upvotes minus downvotes', example: 3 },
        confidence_score: { type: :integer, nullable: true, description: 'Score used by the most_voted sort', example: 7 },
        commentable_type: { type: :string, description: 'The type of resource being commented on (e.g., ProjektPhase, Proposal)', example: 'ProjektPhase' },
        commentable_id: { type: :integer, description: 'The ID of the resource being commented on', example: 10 },
        commentable: {
          type: :object,
          properties: { id: { type: :integer }, type: { type: :string } },
          additionalProperties: false
        },
        projekt_phase: {
          type: :object,
          description: 'The projekt phase the commented resource belongs to',
          properties: { id: { type: :integer }, title: { type: :string, nullable: true }, type: { type: :string } },
          additionalProperties: false
        },
        parent_comment: { '$ref' => '#/components/schemas/CommentReference' },
        child_comments: {
          type: :array,
          description: 'Direct replies to the comment',
          items: { '$ref' => '#/components/schemas/Comment' }
        }
      },
      required: %w[id created_at updated_at commentable_type commentable_id translations],
      additionalProperties: false
    }.freeze

    DOCUMENT_SCHEMA = {
      type: :object,
      description: 'Document attached to the resource',
      properties: {
        id: { type: :integer, description: 'Document ID', example: 4 },
        title: { type: :string, description: 'Document title', example: 'Lageplan' },
        attachment_file_name: { type: :string, nullable: true, description: 'File name', example: 'lageplan.pdf' },
        attachment_file_size: { type: :integer, nullable: true, description: 'File size in bytes', example: 52_431 },
        url: { type: :string, nullable: true, description: 'Download URL', example: 'https://example.com/documents/4/lageplan.pdf' }
      },
      required: %w[id title],
      additionalProperties: false
    }.freeze

    PROJEKT_PHASE_REFERENCE_SCHEMA = {
      type: :object,
      description: 'The projekt phase the resource belongs to',
      properties: {
        id: { type: :integer, example: 25 },
        title: { type: :string, nullable: true, description: 'Tab name of the phase', example: 'Vorschläge' },
        type: { type: :string, example: 'ProjektPhase::ProposalPhase' },
        projekt_id: { type: :integer, example: 3 }
      },
      additionalProperties: false
    }.freeze

    PROJEKT_REFERENCE_SCHEMA = {
      type: :object,
      description: 'The projekt the resource belongs to',
      properties: {
        id: { type: :integer, example: 3 },
        title: { type: :string, nullable: true, description: 'Page title of the projekt', example: 'Marktplatz' }
      },
      additionalProperties: false
    }.freeze

    PROPOSAL_SCHEMA = {
      type: :object,
      properties: {
        id: { type: :integer, description: 'Unique identifier for the proposal', example: 1 },
        title: { type: :string, nullable: true, description: 'Title in the current language', example: 'Green Energy Initiative' },
        description: { type: :string, nullable: true, description: 'Description in the current language', example: 'Implement renewable energy across public buildings' },
        summary: { type: :string, nullable: true, description: 'Short summary in the current language', example: 'Solar panels on schools' },
        retired_explanation: { type: :string, nullable: true, description: 'Why the proposal was retired, in the current language', example: nil },
        translations: Schemas::Miscellaneous.translations_schema(%w[title description summary retired_explanation]),
        external_source: Schemas::Miscellaneous::EXTERNAL_REFERENCE_PROPERTIES[:external_source],
        external_id: Schemas::Miscellaneous::EXTERNAL_REFERENCE_PROPERTIES[:external_id],
        author_id: { type: :integer, nullable: true, description: 'ID of the user who created the proposal. Only returned to admin clients.', example: 20 },
        responsible_name: { type: :string, nullable: true, description: 'Internal responsible-name field. Only returned to admin clients.' },
        admin_accepted: { type: :boolean, description: 'Whether staff accepted the proposal. Unaccepted proposals are never shown to read-only clients. Only returned to admin clients.', example: true },
        author: { '$ref' => '#/components/schemas/Author' },
        on_behalf_of: { type: :string, nullable: true, description: 'Name of the organisation the proposal was submitted on behalf of; shown on the site in place of the author name', example: 'Gartenfreunde e.V.' },
        created_at: { type: :string, format: :date_time, description: 'Timestamp when the proposal was created', example: '2024-01-15T12:00:00Z' },
        updated_at: { type: :string, format: :date_time, description: 'Timestamp when the proposal was last modified', example: '2024-01-18T15:45:00Z' },
        published_at: { type: :string, format: :date_time, nullable: true, description: 'When the proposal was published. Null while it is a draft.', example: '2024-01-15T12:00:00Z' },
        retired_at: { type: :string, format: :date_time, nullable: true, description: 'When the proposal was retired', example: nil },
        retired_reason: { type: :string, nullable: true, enum: [*Proposal::RETIRE_OPTIONS, nil], description: 'Why the proposal was retired', example: nil },
        selected: { type: :boolean, nullable: true, description: 'Whether the proposal was selected', example: false },
        official_answer: { type: :string, nullable: true, description: 'Official answer of the administration', example: '' },
        video_url: { type: :string, nullable: true, description: 'Video explaining the proposal', example: nil },
        projekt_phase_id: { type: :integer, nullable: true, description: 'ID of the projekt phase this proposal belongs to', example: 25 },
        geozone_id: { type: :integer, nullable: true, description: 'ID of the geozone', example: 2 },
        geozone: {
          type: :object,
          properties: { id: { type: :integer }, name: { type: :string } },
          additionalProperties: false
        },
        sentiment_id: { type: :integer, nullable: true, description: 'ID of the sentiment', example: nil },
        sentiment: {
          type: :object,
          properties: { id: { type: :integer }, name: { type: :string, nullable: true }, color: { type: :string, nullable: true } },
          additionalProperties: false
        },
        projekt_labels: {
          type: :array,
          description: 'Labels of the proposal',
          items: {
            type: :object,
            properties: {
              id: { type: :integer },
              name: { type: :string, nullable: true },
              color: { type: :string, nullable: true },
              icon: { type: :string, nullable: true }
            },
            additionalProperties: false
          }
        },
        tags: { type: :array, items: { type: :string }, description: 'Tags of the proposal', example: %w[energy] },
        cached_votes_up: { type: :integer, description: 'Number of supports', example: 12 },
        cached_votes_down: { type: :integer, description: 'Number of negative votes', example: 0 },
        officing_bulk_votes: { type: :integer, nullable: true, description: 'Supports collected offline and entered by staff', example: 0 },
        comments_count: { type: :integer, nullable: true, description: 'Total number of comments on the proposal', example: 12 },
        hot_score: { type: :integer, description: 'Trending score used by the hot_score sort', example: 1200 },
        confidence_score: { type: :integer, description: 'Score used by the confidence_score sort', example: 3 },
        similar_contributions_count: { type: :integer, nullable: true, description: 'Number of other contributions in the same projekt with similar content. Determined freshly on every request and only when the "Pruefung auf aehnliche Beitraege" phase setting is enabled; 0 otherwise.', example: 2 },
        map_location: { '$ref' => '#/components/schemas/MapLocation' },
        projekt_phase: { '$ref' => '#/components/schemas/ProjektPhaseReference' },
        projekt: { '$ref' => '#/components/schemas/ProjektReference' },
        image: { '$ref' => '#/components/schemas/ImageResponse' },
        documents: { type: :array, items: { '$ref' => '#/components/schemas/Document' } }
      },
      required: %w[id created_at updated_at translations tags projekt_labels map_location external_source external_id],
      additionalProperties: false
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
      description: 'Array of document attachments. New documents are attributed to the content author of the API client; the author cannot be set or changed via the API. Upload each file as base64, bare or as a data URI (data:application/pdf;base64,...); invalid base64 returns 422. Returned documents carry a download url.',
      items: {
        type: :object,
        properties: {
          id: { type: :integer, nullable: true },
          title: { type: :string, nullable: true, description: 'Document title; also used for the file name' },
          attachment: { type: :string, nullable: true, description: 'Base64-encoded file' },
          cached_attachment: { type: :string, nullable: true },
          _destroy: { type: :boolean, nullable: true }
        }
      }
    }.freeze

    PROPOSAL_PARAMS_BASE = {
      video_url: { type: :string, nullable: true, description: 'URL to a video explaining the proposal (YouTube, Vimeo, etc.)' },
      geozone_id: { type: :integer, description: 'ID of the geographic zone where the proposal applies' },
      selected: { type: :boolean, nullable: true, description: 'Admin-only: Whether this proposal is selected' },
      on_behalf_of: { type: :string, nullable: true, description: 'Name of the organization or group submitting on behalf of' },
      sentiment_id: { type: :integer, nullable: true, description: 'ID of the sentiment classification for this proposal' },
      official_answer: { type: :string, nullable: true, description: 'Official answer of the administration. Saving it emails the author when proposals.email_on_official_answer is on.' },
      admin_accepted: { type: :boolean, nullable: true, description: 'Whether staff accepted the proposal. Read-only clients never see unaccepted proposals; changing it notifies the author on WhatsApp when enabled.' },
      title: { type: :string, description: 'Title in the current language' },
      description: { type: :string, description: 'Description in the current language' },
      summary: { type: :string, nullable: true, description: 'Short summary in the current language' },
      translations: Schemas::Miscellaneous.translations_schema(%w[title description summary retired_explanation]),
      retired: { type: :boolean, description: 'Set to true to retire the proposal (stamps retired_at). Requires retired_reason and a retired_explanation in every stored language. A retired proposal cannot be un-retired.' },
      retired_reason: { type: :string, enum: Proposal::RETIRE_OPTIONS, description: 'Why the proposal is retired' },
      retired_explanation: { type: :string, description: 'Retirement explanation in the current language' },
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
            map_location_attributes: { '$ref' => '#/components/schemas/MapLocationWriteParams' },
            image_attributes: IMAGE_ATTRIBUTES_CREATE,
            documents_attributes: DOCUMENTS_ATTRIBUTES,
            **Schemas::Miscellaneous::EXTERNAL_REFERENCE_WRITE_PROPERTIES
          ),
          required: %w[title]
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
            geozone_id: { type: :integer, nullable: true, description: 'ID of the geographic zone where the proposal applies' },
            resource_terms: { type: :boolean, nullable: true, description: 'Acceptance of resource terms' },
            published: { type: :boolean, description: 'Set to true to publish a draft proposal (same as PATCH /api/proposals/{id}/publish). A published proposal cannot be turned back into a draft.' },
            map_location_attributes: { '$ref' => '#/components/schemas/MapLocationWriteParams' },
            image_attributes: IMAGE_ATTRIBUTES_UPDATE,
            documents_attributes: DOCUMENTS_ATTRIBUTES
          )
        }
      }
    }.freeze

    def self.all
      {
        Comment: COMMENT_SCHEMA,
        CommentReference: COMMENT_REFERENCE_SCHEMA,
        Document: DOCUMENT_SCHEMA,
        ProjektPhaseReference: PROJEKT_PHASE_REFERENCE_SCHEMA,
        ProjektReference: PROJEKT_REFERENCE_SCHEMA,
        Proposal: PROPOSAL_SCHEMA
      }
    end
  end
end
