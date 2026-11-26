# frozen_string_literal: true

module Schemas
  module DeficiencyReports
    TRANSLATED_ATTRIBUTES = %w[title description summary official_answer reporter_answer].freeze

    OFFICIAL_ANSWER_DOCUMENT_SCHEMA = {
      type: :object,
      description: 'File attached to the official answer',
      properties: {
        id: { type: :integer, description: 'ID of the attachment; send it in remove_official_answer_document_ids to remove the file', example: 31 },
        filename: { type: :string, example: 'antwort.pdf' },
        content_type: { type: :string, example: 'application/pdf' },
        byte_size: { type: :integer, example: 48_210 },
        url: { type: :string, description: 'Download URL', example: 'https://example.com/rails/active_storage/blobs/antwort.pdf' }
      },
      required: %w[id filename url],
      additionalProperties: false
    }.freeze

    DEFICIENCY_REPORT_SCHEMA = {
      type: :object,
      properties: {
        id: { type: :integer, description: 'Unique identifier for the deficiency report', example: 1 },
        code: { type: :string, description: 'Reference code shown on the public page', example: 'CONSUL-DF-2024-01-1' },
        title: { type: :string, description: 'Title in the current language', example: 'Pothole on Main Street' },
        description: { type: :string, nullable: true, description: 'Description in the current language', example: 'Large pothole causing safety concerns near intersection' },
        summary: { type: :string, nullable: true, description: 'Summary in the current language' },
        official_answer: { type: :string, nullable: true, description: 'Official answer shown publicly above the report, in the current language' },
        reporter_answer: { type: :string, nullable: true, description: 'Answer e-mailed to the reporter and not shown publicly. Only returned to admin clients.' },
        translations: Schemas::Miscellaneous.translations_schema(TRANSLATED_ATTRIBUTES).merge(
          description: 'Texts per language, keyed by locale. reporter_answer is only returned to admin clients.'
        ),
        video_url: { type: :string, nullable: true, description: 'URL of a video about the report' },
        cached_votes_up: { type: :integer, nullable: true, description: 'Number of likes', example: 4 },
        cached_votes_down: { type: :integer, nullable: true, description: 'Number of dislikes', example: 0 },
        cached_votes_total: { type: :integer, nullable: true, description: 'Number of votes', example: 4 },
        cached_votes_score: { type: :integer, nullable: true, description: 'Likes minus dislikes', example: 4 },
        comments_count: { type: :integer, nullable: true, description: 'Number of comments', example: 2 },
        deficiency_report_category_id: { type: :integer, description: 'ID of the category', example: 3 },
        deficiency_report_subcategory_id: { type: :integer, nullable: true, description: 'ID of the subcategory', example: 7 },
        deficiency_report_status_id: { type: :integer, nullable: true, description: 'ID of the status', example: 1 },
        deficiency_report_intake_channel_id: { type: :integer, nullable: true, description: 'ID of the channel the report came in through. Only returned to admin clients.', example: 2 },
        intake_channel: {
          type: :object,
          nullable: true,
          description: 'Channel the report came in through. Only returned to admin clients.',
          properties: { id: { type: :integer }, name: { type: :string } },
          additionalProperties: false
        },
        author_id: { type: :integer, nullable: true, description: 'ID of the user who reported the deficiency. Only returned to admin clients.', example: 18 },
        on_behalf_of: { type: :string, nullable: true, description: 'Name the report was filed on behalf of. Only returned to admin clients.' },
        admin_accepted: { type: :boolean, nullable: true, description: 'Whether staff accepted the report. Only returned to admin clients; read-only clients only ever get accepted reports.' },
        assigned_at: { type: :string, format: :date_time, nullable: true, description: 'When the report was assigned to its responsible. Only returned to admin clients.' },
        status_changed_at: { type: :string, format: :date_time, nullable: true, description: 'When the status last changed' },
        archived_at: { type: :string, format: :date_time, nullable: true, description: 'When the report was archived' },
        author: { '$ref' => '#/components/schemas/Author' },
        category: {
          type: :object,
          description: 'Category of the report',
          properties: {
            id: { type: :integer, description: 'Category ID' },
            name: { type: :string, description: 'Category name' },
            icon: { type: :string, nullable: true, description: 'Font Awesome icon name' },
            color: { type: :string, nullable: true, description: 'Colour of the category' },
            warning_text: { type: :string, nullable: true, description: 'Warning shown to citizens who pick the category in the report form' }
          },
          additionalProperties: false
        },
        subcategory: {
          type: :object,
          description: 'Subcategory of the report',
          properties: { id: { type: :integer }, name: { type: :string, nullable: true } },
          additionalProperties: false
        },
        status: {
          type: :object,
          description: 'Current status of the report',
          properties: {
            id: { type: :integer, description: 'Status ID' },
            title: { type: :string, nullable: true, description: 'Status title' },
            color: { type: :string, nullable: true },
            icon: { type: :string, nullable: true },
            archive_reports: { type: :boolean, nullable: true, description: 'Reports in this status are closed and archived after a week' }
          },
          additionalProperties: false
        },
        responsible: {
          type: :object,
          description: 'Officer or officer group responsible for the report. Only returned to admin clients.',
          properties: {
            id: { type: :integer },
            type: { type: :string, enum: ['DeficiencyReport::Officer', 'DeficiencyReport::OfficerGroup'] },
            name: { type: :string, nullable: true }
          },
          additionalProperties: false
        },
        map_location: { '$ref' => '#/components/schemas/MapLocation' },
        tags: { type: :array, items: { type: :string }, description: 'Tags of the report' },
        image: { '$ref' => '#/components/schemas/ImageResponse' },
        documents: { type: :array, description: 'Documents the reporter attached', items: { '$ref' => '#/components/schemas/Document' } },
        official_answer_documents: { type: :array, description: 'Files attached to the official answer', items: OFFICIAL_ANSWER_DOCUMENT_SCHEMA },
        created_at: { type: :string, format: :date_time, description: 'Timestamp when the report was created', example: '2024-01-20T14:30:00Z' },
        updated_at: { type: :string, format: :date_time, description: 'Timestamp when the report was last modified', example: '2024-01-22T10:15:00Z' }
      },
      required: %w[id code title translations deficiency_report_category_id map_location tags documents official_answer_documents created_at updated_at],
      additionalProperties: false
    }.freeze

    DEFICIENCY_REPORT_WRITE_PARAMS = {
      type: :object,
      properties: {
        deficiency_report: {
          type: :object,
          description: 'Report attributes. On create deficiency_report_category_id, a title and (when the instance requires it) a location are needed; the author is the content author of the API client, terms acceptance and admin acceptance are set by the server.',
          properties: {
            deficiency_report_category_id: { type: :integer, description: 'ID of the category' },
            deficiency_report_subcategory_id: { type: :integer, nullable: true, description: 'ID of a subcategory of the same category (GET /api/deficiency_report_subcategories). A subcategory of another category is dropped.' },
            deficiency_report_status_id: { type: :integer, nullable: true },
            title: { type: :string, description: 'Title in the current language' },
            description: { type: :string, nullable: true, description: 'Description in the current language' },
            summary: { type: :string, nullable: true, description: 'Summary in the current language' },
            official_answer: { type: :string, nullable: true, description: 'Public official answer in the current language' },
            reporter_answer: { type: :string, nullable: true, description: 'Answer e-mailed to the reporter and not shown publicly; used when the setting "separate reporter answer" is enabled, in which case official_answer is the public answer only' },
            translations: Schemas::Miscellaneous.translations_schema(TRANSLATED_ATTRIBUTES),
            on_behalf_of: { type: :string, nullable: true, description: 'Name of the person or organisation the report is filed on behalf of' },
            deficiency_report_intake_channel_id: { type: :integer, nullable: true, description: 'ID of the intake channel the report reached the municipality through, as listed by GET /api/deficiency_report_intake_channels. Required for a report filed on_behalf_of a citizen when the setting "intake channel required for on-behalf-of reports" is on; otherwise the default channel is used. An id that does not exist is rejected with 422.' },
            video_url: { type: :string, nullable: true, description: 'URL to a video documenting the deficiency (YouTube, Vimeo, etc.)' },
            responsible_id: { type: :integer, nullable: true, description: 'ID of the officer or officer group assigned to address this deficiency' },
            responsible_type: { type: :string, nullable: true, enum: ['DeficiencyReport::Officer', 'DeficiencyReport::OfficerGroup'], description: 'Type of the responsible party. Only officers and officer groups can be made responsible; any other type, or an id that does not exist, is rejected with 422.' },
            tag_list: { type: :string, nullable: true, description: 'Comma-separated list of tags' },
            map_location_attributes: { '$ref' => '#/components/schemas/MapLocationWriteParams' },
            documents_attributes: {
              type: :array,
              description: 'Documents of the report (PDFs etc.). Upload each file as base64, bare or as a data URI (data:application/pdf;base64,...). Add new documents, or remove one by sending its id with _destroy=true. New documents are attributed to the content author of the API client.',
              items: {
                type: :object,
                properties: {
                  id: { type: :integer, description: 'ID of an existing document; omit for new documents' },
                  title: { type: :string, description: 'Document title; also used for the file name' },
                  attachment: { type: :string, description: 'Base64-encoded file. Invalid base64 returns 422.' },
                  _destroy: { type: :boolean, description: 'Set to true to remove this document' }
                }
              }
            },
            official_answer_documents: {
              type: :array,
              description: 'Files to append to the official answer, base64 encoded. Type, size and number are checked against the document settings of the instance.',
              items: {
                type: :object,
                properties: {
                  title: { type: :string, description: 'Used for the file name' },
                  attachment: { type: :string, description: 'Base64-encoded file, bare or as a data URI' }
                },
                required: ['attachment']
              }
            },
            remove_official_answer_document_ids: { type: :array, items: { type: :integer }, description: 'IDs of official answer files to remove' },
            image_attributes: { '$ref' => '#/components/schemas/ImageAttributesApi' }
          }
        }
      },
      required: ['deficiency_report']
    }.freeze

    DEFICIENCY_REPORT_CATEGORY_SCHEMA = {
      type: :object,
      properties: {
        id: { type: :integer, description: 'Unique identifier for the category', example: 1 },
        name: { type: :string, description: 'Name in the current language', example: 'Infrastructure' },
        translations: Schemas::Miscellaneous.translations_schema(%w[name]),
        icon: { type: :string, nullable: true, description: 'Font Awesome icon name', example: 'road' },
        color: { type: :string, nullable: true, description: 'Colour of the category', example: '#004a83' },
        given_order: { type: :integer, nullable: true, description: 'Display order (lower first)', example: 1 },
        warning_text: { type: :string, nullable: true, description: 'Warning shown to citizens who pick the category in the report form', example: 'For emergencies call 112.' },
        deficiency_reports_count: { type: :integer, description: 'Number of published reports in the category', example: 12 },
        default_responsible: {
          type: :object,
          nullable: true,
          description: 'Officer or officer group new reports in this category are assigned to. Only returned to admin clients.',
          properties: {
            id: { type: :integer },
            type: { type: :string, enum: ['DeficiencyReport::Officer', 'DeficiencyReport::OfficerGroup'] },
            name: { type: :string, nullable: true }
          },
          additionalProperties: false
        },
        created_at: { type: :string, format: :date_time, description: 'Timestamp when the category was created', example: '2024-01-01T00:00:00Z' },
        updated_at: { type: :string, format: :date_time, description: 'Timestamp when the category was last modified', example: '2024-01-01T00:00:00Z' }
      },
      required: %w[id name translations deficiency_reports_count created_at updated_at],
      additionalProperties: false
    }.freeze

    DEFICIENCY_REPORT_STATUS_SCHEMA = {
      type: :object,
      properties: {
        id: { type: :integer, example: 1 },
        title: { type: :string, nullable: true, description: 'Title in the current language', example: 'In Bearbeitung' },
        description: { type: :string, nullable: true, description: 'Description in the current language' },
        translations: Schemas::Miscellaneous.translations_schema(%w[title description]),
        color: { type: :string, nullable: true, example: 'orange' },
        icon: { type: :string, nullable: true, example: 'hourglass-half' },
        given_order: { type: :integer, nullable: true, description: 'Display order (lower first)', example: 2 },
        archive_reports: { type: :boolean, nullable: true, description: 'Reports in this status are closed and archived after a week', example: false },
        notice_text: { type: :string, nullable: true, description: 'Text e-mailed to the reporter when a report changes to this status. Only returned to admin clients.' },
        reminder_delay: { type: :integer, nullable: true, description: 'Days after which the responsible is reminded of a report in this status. Only returned to admin clients.' },
        created_at: { type: :string, format: :date_time },
        updated_at: { type: :string, format: :date_time }
      },
      required: %w[id translations created_at updated_at],
      additionalProperties: false
    }.freeze

    DEFICIENCY_REPORT_SUBCATEGORY_SCHEMA = {
      type: :object,
      properties: {
        id: { type: :integer, example: 7 },
        deficiency_report_category_id: { type: :integer, description: 'ID of the category the subcategory belongs to', example: 3 },
        name: { type: :string, nullable: true, description: 'Name in the current language', example: 'Schlagloch' },
        translations: Schemas::Miscellaneous.translations_schema(%w[name]),
        given_order: { type: :integer, nullable: true, description: 'Display order within the category', example: 1 },
        created_at: { type: :string, format: :date_time },
        updated_at: { type: :string, format: :date_time }
      },
      required: %w[id deficiency_report_category_id translations created_at updated_at],
      additionalProperties: false
    }.freeze

    DEFICIENCY_REPORT_ANSWER_TEMPLATE_SCHEMA = {
      type: :object,
      properties: {
        id: { type: :integer, example: 1 },
        title: { type: :string, nullable: true, description: 'Name of the template', example: 'Weitergeleitet' },
        text: { type: :string, nullable: true, description: 'Answer text staff start from', example: 'Wir haben Ihre Meldung an das zuständige Amt weitergeleitet.' },
        created_at: { type: :string, format: :date_time },
        updated_at: { type: :string, format: :date_time }
      },
      required: %w[id created_at updated_at],
      additionalProperties: false
    }.freeze

    IMAGE_ATTRIBUTES_SCHEMA = {
      type: :object,
      properties: {
        title: { type: :string, nullable: true, description: 'Title or caption for the image' },
        attachment: { type: :string, description: 'Base64-encoded image data' },
        credits: { type: :string, nullable: true, description: 'Attribution or credits for the image' },
        ai_generated: { type: :boolean, nullable: true, description: 'Set to true when the image was created or edited with AI; the public page then shows the AI disclosure label' },
        _destroy: { type: :boolean, nullable: true, description: 'Flag to delete the image' }
      }
    }.freeze

    def self.all
      {
        DeficiencyReport: DEFICIENCY_REPORT_SCHEMA,
        DeficiencyReportWriteParams: DEFICIENCY_REPORT_WRITE_PARAMS,
        DeficiencyReportCategory: DEFICIENCY_REPORT_CATEGORY_SCHEMA,
        DeficiencyReportStatus: DEFICIENCY_REPORT_STATUS_SCHEMA,
        DeficiencyReportSubcategory: DEFICIENCY_REPORT_SUBCATEGORY_SCHEMA,
        DeficiencyReportAnswerTemplate: DEFICIENCY_REPORT_ANSWER_TEMPLATE_SCHEMA,
        ImageAttributes: IMAGE_ATTRIBUTES_SCHEMA
      }
    end
  end
end
