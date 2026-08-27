# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2026_08_27_130954) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_trgm"
  enable_extension "plpgsql"
  enable_extension "unaccent"

  create_table "active_poll_translations", id: :serial, force: :cascade do |t|
    t.integer "active_poll_id", null: false
    t.string "locale", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "description"
    t.index ["active_poll_id"], name: "index_active_poll_translations_on_active_poll_id"
    t.index ["locale"], name: "index_active_poll_translations_on_locale"
  end

  create_table "active_polls", id: :serial, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.bigint "byte_size", null: false
    t.string "checksum", null: false
    t.datetime "created_at", null: false
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "activities", id: :serial, force: :cascade do |t|
    t.integer "user_id"
    t.string "action"
    t.string "actionable_type"
    t.integer "actionable_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["actionable_id", "actionable_type"], name: "index_activities_on_actionable_id_and_actionable_type"
    t.index ["user_id"], name: "index_activities_on_user_id"
  end

  create_table "admin_assets", id: :serial, force: :cascade do |t|
    t.string "data_file_name", null: false
    t.string "data_content_type"
    t.integer "data_file_size"
    t.string "data_fingerprint"
    t.string "type", limit: 30
    t.integer "width"
    t.integer "height"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "title", default: ""
    t.string "description", default: ""
    t.tsvector "tsv"
    t.string "alt_text", default: ""
    t.bigint "projekt_id"
    t.index ["projekt_id"], name: "index_admin_assets_on_projekt_id"
    t.index ["type"], name: "index_admin_assets_on_type"
  end

  create_table "admin_images", force: :cascade do |t|
    t.string "data_file_name", null: false
    t.string "data_content_type"
    t.integer "data_file_size"
    t.integer "width"
    t.integer "height"
    t.string "title", default: ""
    t.string "description", default: ""
    t.string "alt_text", default: ""
    t.tsvector "tsv"
    t.bigint "projekt_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.bigint "user_id"
    t.index ["projekt_id"], name: "index_admin_images_on_projekt_id"
    t.index ["tsv"], name: "index_admin_images_on_tsv", using: :gin
    t.index ["user_id"], name: "index_admin_images_on_user_id"
  end

  create_table "admin_notification_translations", id: :serial, force: :cascade do |t|
    t.integer "admin_notification_id", null: false
    t.string "locale", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "title"
    t.text "body"
    t.index ["admin_notification_id"], name: "index_admin_notification_translations_on_admin_notification_id"
    t.index ["locale"], name: "index_admin_notification_translations_on_locale"
  end

  create_table "admin_notifications", id: :serial, force: :cascade do |t|
    t.string "link"
    t.string "segment_recipient"
    t.integer "recipients_count"
    t.date "sent_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "administrators", id: :serial, force: :cascade do |t|
    t.integer "user_id"
    t.string "description"
    t.index ["user_id"], name: "index_administrators_on_user_id"
  end

  create_table "age_range_projekt_phases", force: :cascade do |t|
    t.bigint "age_range_id"
    t.bigint "projekt_phase_id"
    t.string "used_for", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["age_range_id"], name: "index_age_range_projekt_phases_on_age_range_id"
    t.index ["projekt_phase_id"], name: "index_age_range_projekt_phases_on_projekt_phase_id"
  end

  create_table "age_range_translations", force: :cascade do |t|
    t.bigint "age_range_id", null: false
    t.string "locale", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name"
    t.index ["age_range_id"], name: "index_age_range_translations_on_age_range_id"
    t.index ["locale"], name: "index_age_range_translations_on_locale"
  end

  create_table "age_ranges", force: :cascade do |t|
    t.integer "order"
    t.integer "min_age"
    t.integer "max_age"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "only_for_stats", default: false
  end

  create_table "ahoy_events", force: :cascade do |t|
    t.bigint "visit_id"
    t.bigint "user_id"
    t.string "name"
    t.jsonb "properties"
    t.datetime "time"
    t.index ["name", "time"], name: "index_ahoy_events_on_name_and_time"
    t.index ["properties"], name: "index_ahoy_events_on_properties_jsonb_path_ops", opclass: :jsonb_path_ops, using: :gin
    t.index ["user_id"], name: "index_ahoy_events_on_user_id"
    t.index ["visit_id"], name: "index_ahoy_events_on_visit_id"
  end

  create_table "ahoy_events_old", id: :uuid, default: nil, force: :cascade do |t|
    t.uuid "visit_id"
    t.integer "user_id"
    t.string "name"
    t.jsonb "properties"
    t.datetime "time"
    t.string "ip"
    t.index ["name", "time"], name: "index_ahoy_events_old_on_name_and_time"
    t.index ["time"], name: "index_ahoy_events_old_on_time"
    t.index ["user_id"], name: "index_ahoy_events_old_on_user_id"
    t.index ["visit_id"], name: "index_ahoy_events_old_on_visit_id"
  end

  create_table "ahoy_visits", force: :cascade do |t|
    t.string "visit_token"
    t.string "visitor_token"
    t.bigint "user_id"
    t.string "ip"
    t.text "user_agent"
    t.text "referrer"
    t.string "referring_domain"
    t.text "landing_page"
    t.string "browser"
    t.string "os"
    t.string "device_type"
    t.string "country"
    t.string "region"
    t.string "city"
    t.string "utm_source"
    t.string "utm_medium"
    t.string "utm_term"
    t.string "utm_content"
    t.string "utm_campaign"
    t.datetime "started_at"
    t.index ["user_id"], name: "index_ahoy_visits_on_user_id"
    t.index ["visit_token"], name: "index_ahoy_visits_on_visit_token", unique: true
  end

  create_table "ai_chat_messages", force: :cascade do |t|
    t.bigint "ai_chat_id", null: false
    t.string "role", null: false
    t.text "content"
    t.string "status", default: "scheduled", null: false
    t.jsonb "attached_documents", default: [], null: false
    t.string "custom_command"
    t.bigint "user_message_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.jsonb "tool_activity", default: [], null: false
    t.index ["ai_chat_id", "created_at"], name: "index_ai_chat_messages_on_ai_chat_id_and_created_at"
    t.index ["ai_chat_id"], name: "index_ai_chat_messages_on_ai_chat_id"
    t.index ["user_message_id"], name: "index_ai_chat_messages_on_user_message_id"
  end

  create_table "ai_chats", force: :cascade do |t|
    t.string "resource_type", null: false
    t.bigint "resource_id", null: false
    t.string "ai_provider"
    t.string "ai_model"
    t.boolean "running", default: false, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["resource_type", "resource_id"], name: "index_ai_chats_on_resource_type_and_resource_id"
  end

  create_table "ai_usage_records", force: :cascade do |t|
    t.date "period_month", null: false
    t.string "feature", null: false
    t.string "provider", null: false
    t.string "model", null: false
    t.integer "request_count", default: 0, null: false
    t.integer "unpriced_request_count", default: 0, null: false
    t.bigint "input_tokens", default: 0, null: false
    t.bigint "output_tokens", default: 0, null: false
    t.bigint "cache_read_tokens", default: 0, null: false
    t.bigint "cache_write_tokens", default: 0, null: false
    t.bigint "thinking_tokens", default: 0, null: false
    t.float "audio_seconds", default: 0.0, null: false
    t.decimal "cost_total", precision: 14, scale: 6, default: "0.0", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.bigint "version", default: 0, null: false
    t.index ["period_month", "feature", "provider", "model"], name: "index_ai_usage_records_on_period_and_breakdown", unique: true
    t.index ["period_month"], name: "index_ai_usage_records_on_period_month"
  end

  create_table "api_clients", force: :cascade do |t|
    t.string "name"
    t.string "access_level"
    t.string "service_user_email"
    t.string "access_token"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.boolean "use_system_user", default: true, null: false
  end

  create_table "api_request_logs", force: :cascade do |t|
    t.string "http_method", null: false
    t.string "request_path", null: false
    t.string "full_url"
    t.jsonb "query_params", default: {}, null: false
    t.jsonb "body_params", default: {}, null: false
    t.integer "response_status"
    t.integer "api_client_id"
    t.boolean "pushed_to_dt", default: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.float "duration_ms"
    t.float "db_runtime"
    t.float "view_runtime"
    t.index ["api_client_id"], name: "index_api_request_logs_on_api_client_id"
    t.index ["created_at"], name: "index_api_request_logs_on_created_at"
    t.index ["pushed_to_dt"], name: "index_api_request_logs_on_pushed_to_dt"
    t.index ["request_path"], name: "index_api_request_logs_on_request_path"
  end

  create_table "apps", force: :cascade do |t|
    t.integer "status"
    t.string "codename"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "audits", id: :serial, force: :cascade do |t|
    t.integer "auditable_id"
    t.string "auditable_type"
    t.integer "associated_id"
    t.string "associated_type"
    t.integer "user_id"
    t.string "user_type"
    t.string "username"
    t.string "action"
    t.jsonb "audited_changes"
    t.integer "version", default: 0
    t.string "comment"
    t.string "remote_address"
    t.string "request_uuid"
    t.datetime "created_at"
    t.index ["associated_type", "associated_id"], name: "associated_index"
    t.index ["auditable_type", "auditable_id", "version"], name: "auditable_index"
    t.index ["created_at"], name: "index_audits_on_created_at"
    t.index ["request_uuid"], name: "index_audits_on_request_uuid"
    t.index ["user_id", "user_type"], name: "user_index"
  end

  create_table "awesome_icons", force: :cascade do |t|
    t.string "name", null: false
    t.string "unicode", null: false
    t.boolean "shortlisted", default: false, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["name"], name: "index_awesome_icons_on_name", unique: true
  end

  create_table "banner_sections", id: :serial, force: :cascade do |t|
    t.integer "banner_id"
    t.integer "web_section_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "banner_translations", id: :serial, force: :cascade do |t|
    t.integer "banner_id", null: false
    t.string "locale", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "title"
    t.text "description"
    t.datetime "hidden_at"
    t.index ["banner_id"], name: "index_banner_translations_on_banner_id"
    t.index ["hidden_at"], name: "index_banner_translations_on_hidden_at"
    t.index ["locale"], name: "index_banner_translations_on_locale"
  end

  create_table "banners", id: :serial, force: :cascade do |t|
    t.string "target_url"
    t.date "post_started_at"
    t.date "post_ended_at"
    t.datetime "hidden_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "background_color"
    t.text "font_color"
    t.index ["hidden_at"], name: "index_banners_on_hidden_at"
  end

  create_table "budget_administrators", id: :serial, force: :cascade do |t|
    t.integer "budget_id"
    t.integer "administrator_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["administrator_id"], name: "index_budget_administrators_on_administrator_id"
    t.index ["budget_id"], name: "index_budget_administrators_on_budget_id"
  end

  create_table "budget_ballot_lines", id: :serial, force: :cascade do |t|
    t.integer "ballot_id"
    t.integer "investment_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "budget_id"
    t.integer "group_id"
    t.integer "heading_id"
    t.integer "line_weight", default: 1
    t.index ["ballot_id", "investment_id"], name: "index_budget_ballot_lines_on_ballot_id_and_investment_id", unique: true
    t.index ["ballot_id"], name: "index_budget_ballot_lines_on_ballot_id"
    t.index ["budget_id"], name: "index_budget_ballot_lines_on_budget_id"
    t.index ["group_id"], name: "index_budget_ballot_lines_on_group_id"
    t.index ["heading_id"], name: "index_budget_ballot_lines_on_heading_id"
    t.index ["investment_id"], name: "index_budget_ballot_lines_on_investment_id"
  end

  create_table "budget_ballots", id: :serial, force: :cascade do |t|
    t.integer "user_id"
    t.integer "budget_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "ballot_lines_count", default: 0
    t.boolean "physical", default: false
    t.integer "poll_ballot_id"
    t.boolean "conditional", default: false
  end

  create_table "budget_content_blocks", id: :serial, force: :cascade do |t|
    t.integer "heading_id"
    t.text "body"
    t.string "locale"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["heading_id"], name: "index_budget_content_blocks_on_heading_id"
  end

  create_table "budget_group_translations", id: :serial, force: :cascade do |t|
    t.integer "budget_group_id", null: false
    t.string "locale", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name"
    t.index ["budget_group_id"], name: "index_budget_group_translations_on_budget_group_id"
    t.index ["locale"], name: "index_budget_group_translations_on_locale"
  end

  create_table "budget_groups", id: :serial, force: :cascade do |t|
    t.integer "budget_id"
    t.string "slug"
    t.integer "max_votable_headings", default: 1
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["budget_id"], name: "index_budget_groups_on_budget_id"
  end

  create_table "budget_heading_translations", id: :serial, force: :cascade do |t|
    t.integer "budget_heading_id", null: false
    t.string "locale", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name"
    t.index ["budget_heading_id"], name: "index_budget_heading_translations_on_budget_heading_id"
    t.index ["locale"], name: "index_budget_heading_translations_on_locale"
  end

  create_table "budget_headings", id: :serial, force: :cascade do |t|
    t.integer "group_id"
    t.bigint "price"
    t.integer "population"
    t.string "slug"
    t.boolean "allow_custom_content", default: false
    t.text "latitude"
    t.text "longitude"
    t.integer "max_ballot_lines", default: 1
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["group_id"], name: "index_budget_headings_on_group_id"
  end

  create_table "budget_investment_translations", id: :serial, force: :cascade do |t|
    t.integer "budget_investment_id", null: false
    t.string "locale", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "title"
    t.text "description"
    t.datetime "hidden_at"
    t.index ["budget_investment_id"], name: "index_budget_investment_translations_on_budget_investment_id"
    t.index ["hidden_at"], name: "index_budget_investment_translations_on_hidden_at"
    t.index ["locale"], name: "index_budget_investment_translations_on_locale"
  end

  create_table "budget_investments", id: :serial, force: :cascade do |t|
    t.integer "author_id"
    t.integer "administrator_id"
    t.string "external_url"
    t.bigint "price"
    t.string "feasibility", limit: 15, default: "undecided"
    t.text "price_explanation"
    t.text "unfeasibility_explanation"
    t.boolean "valuation_finished", default: false
    t.integer "valuator_assignments_count", default: 0
    t.bigint "price_first_year"
    t.string "duration"
    t.datetime "hidden_at"
    t.integer "cached_votes_up", default: 0
    t.integer "comments_count", default: 0
    t.integer "confidence_score", default: 0, null: false
    t.integer "physical_votes", default: 0
    t.tsvector "tsv"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "heading_id"
    t.string "responsible_name"
    t.integer "budget_id"
    t.integer "group_id"
    t.boolean "selected", default: false
    t.string "location"
    t.string "organization_name"
    t.datetime "unfeasible_email_sent_at"
    t.integer "ballot_lines_count", default: 0
    t.integer "previous_heading_id"
    t.boolean "winner", default: false
    t.boolean "incompatible", default: false
    t.integer "community_id"
    t.boolean "visible_to_valuators", default: false
    t.integer "valuator_group_assignments_count", default: 0
    t.datetime "confirmed_hide_at"
    t.datetime "ignored_flag_at"
    t.integer "flags_count", default: 0
    t.integer "original_heading_id"
    t.integer "implementation_performer", default: 1
    t.text "implementation_contribution"
    t.string "user_cost_estimate"
    t.string "on_behalf_of"
    t.integer "qualified_total_ballot_line_weight", default: 0
    t.string "video_url"
    t.bigint "sentiment_id"
    t.text "valuator_explanation"
    t.time "email_on_feasibility_sent_at"
    t.time "email_on_selected_sent_at"
    t.boolean "preselected", default: false
    t.boolean "draft", default: false, null: false
    t.text "ai_idea_text"
    t.jsonb "ai_evaluation_result"
    t.text "ai_image_prompt"
    t.datetime "published_at"
    t.string "source"
    t.string "source_collection"
    t.string "external_id"
    t.string "external_source_url"
    t.bigint "masterportal_pin_id"
    t.boolean "generated_image", default: false, null: false
    t.index ["administrator_id"], name: "index_budget_investments_on_administrator_id"
    t.index ["author_id"], name: "index_budget_investments_on_author_id"
    t.index ["budget_id", "source", "source_collection"], name: "index_budget_investments_on_budget_source_collection"
    t.index ["budget_id"], name: "index_budget_investments_on_budget_id"
    t.index ["community_id"], name: "index_budget_investments_on_community_id"
    t.index ["draft"], name: "index_budget_investments_on_draft"
    t.index ["external_id"], name: "index_budget_investments_on_external_id"
    t.index ["group_id"], name: "index_budget_investments_on_group_id"
    t.index ["heading_id"], name: "index_budget_investments_on_heading_id"
    t.index ["incompatible"], name: "index_budget_investments_on_incompatible"
    t.index ["masterportal_pin_id"], name: "index_budget_investments_on_masterportal_pin_id"
    t.index ["selected"], name: "index_budget_investments_on_selected"
    t.index ["sentiment_id"], name: "index_budget_investments_on_sentiment_id"
    t.index ["source", "external_id", "budget_id"], name: "index_budget_investments_on_source_external_id_budget_id", unique: true
    t.index ["tsv"], name: "index_budget_investments_on_tsv", using: :gin
  end

  create_table "budget_phase_translations", id: :serial, force: :cascade do |t|
    t.integer "budget_phase_id", null: false
    t.string "locale", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "description"
    t.text "summary"
    t.string "name"
    t.string "main_link_text"
    t.string "main_link_url"
    t.index ["budget_phase_id"], name: "index_budget_phase_translations_on_budget_phase_id"
    t.index ["locale"], name: "index_budget_phase_translations_on_locale"
  end

  create_table "budget_phases", id: :serial, force: :cascade do |t|
    t.integer "budget_id"
    t.integer "next_phase_id"
    t.string "kind", null: false
    t.datetime "starts_at"
    t.datetime "ends_at"
    t.boolean "enabled", default: true
    t.index ["ends_at"], name: "index_budget_phases_on_ends_at"
    t.index ["kind"], name: "index_budget_phases_on_kind"
    t.index ["next_phase_id"], name: "index_budget_phases_on_next_phase_id"
    t.index ["starts_at"], name: "index_budget_phases_on_starts_at"
  end

  create_table "budget_reclassified_votes", id: :serial, force: :cascade do |t|
    t.integer "user_id"
    t.integer "investment_id"
    t.string "reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "budget_translations", id: :serial, force: :cascade do |t|
    t.integer "budget_id", null: false
    t.string "locale", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name"
    t.string "main_link_text"
    t.string "main_link_url"
    t.index ["budget_id"], name: "index_budget_translations_on_budget_id"
    t.index ["locale"], name: "index_budget_translations_on_locale"
  end

  create_table "budget_valuator_assignments", id: :serial, force: :cascade do |t|
    t.integer "valuator_id"
    t.integer "investment_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["investment_id"], name: "index_budget_valuator_assignments_on_investment_id"
  end

  create_table "budget_valuator_group_assignments", id: :serial, force: :cascade do |t|
    t.integer "valuator_group_id"
    t.integer "investment_id"
  end

  create_table "budget_valuators", id: :serial, force: :cascade do |t|
    t.integer "budget_id"
    t.integer "valuator_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["budget_id"], name: "index_budget_valuators_on_budget_id"
    t.index ["valuator_id"], name: "index_budget_valuators_on_valuator_id"
  end

  create_table "budgets", id: :serial, force: :cascade do |t|
    t.string "currency_symbol", limit: 10
    t.string "phase", limit: 40, default: "accepting"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "description_accepting"
    t.text "description_reviewing"
    t.text "description_selecting"
    t.text "description_valuating"
    t.text "description_balloting"
    t.text "description_reviewing_ballots"
    t.text "description_finished"
    t.string "slug"
    t.text "description_drafting"
    t.text "description_publishing_prices"
    t.text "description_informing"
    t.string "voting_style", default: "knapsack"
    t.boolean "published"
    t.bigint "projekt_id"
    t.boolean "hide_money", default: false
    t.integer "max_number_of_winners", default: 0
    t.bigint "projekt_phase_id"
    t.boolean "show_percentage_values_only", default: false
    t.boolean "show_results_after_first_vote", default: false
    t.integer "max_preselected", default: 0
    t.index ["projekt_id"], name: "index_budgets_on_projekt_id"
    t.index ["projekt_phase_id"], name: "index_budgets_on_projekt_phase_id"
  end

  create_table "campaigns", id: :serial, force: :cascade do |t|
    t.string "name"
    t.string "track_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "city_street_projekt_phases", force: :cascade do |t|
    t.bigint "city_street_id"
    t.bigint "projekt_phase_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["city_street_id"], name: "index_city_street_projekt_phases_on_city_street_id"
    t.index ["projekt_phase_id"], name: "index_city_street_projekt_phases_on_projekt_phase_id"
  end

  create_table "city_streets", force: :cascade do |t|
    t.string "name"
    t.string "plz"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "comment_translations", id: :serial, force: :cascade do |t|
    t.integer "comment_id", null: false
    t.string "locale", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "body"
    t.datetime "hidden_at"
    t.index ["comment_id"], name: "index_comment_translations_on_comment_id"
    t.index ["hidden_at"], name: "index_comment_translations_on_hidden_at"
    t.index ["locale"], name: "index_comment_translations_on_locale"
  end

  create_table "comments", id: :serial, force: :cascade do |t|
    t.integer "commentable_id"
    t.string "commentable_type"
    t.string "subject"
    t.integer "user_id", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "hidden_at"
    t.integer "flags_count", default: 0
    t.datetime "ignored_flag_at"
    t.integer "moderator_id"
    t.integer "administrator_id"
    t.integer "cached_votes_total", default: 0
    t.integer "cached_votes_up", default: 0
    t.integer "cached_votes_down", default: 0
    t.datetime "confirmed_hide_at"
    t.string "ancestry"
    t.integer "confidence_score", default: 0, null: false
    t.boolean "valuation", default: false
    t.index ["ancestry"], name: "index_comments_on_ancestry"
    t.index ["cached_votes_down"], name: "index_comments_on_cached_votes_down"
    t.index ["cached_votes_total"], name: "index_comments_on_cached_votes_total"
    t.index ["cached_votes_up"], name: "index_comments_on_cached_votes_up"
    t.index ["commentable_id", "commentable_type"], name: "index_comments_on_commentable_id_and_commentable_type"
    t.index ["confidence_score"], name: "index_comments_on_confidence_score"
    t.index ["hidden_at"], name: "index_comments_on_hidden_at"
    t.index ["user_id"], name: "index_comments_on_user_id"
    t.index ["valuation"], name: "index_comments_on_valuation"
  end

  create_table "communities", id: :serial, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "dashboard_actions", id: :serial, force: :cascade do |t|
    t.string "title", limit: 80
    t.text "description"
    t.boolean "request_to_administrators", default: false
    t.integer "day_offset", default: 0
    t.integer "required_supports", default: 0
    t.integer "order", default: 0
    t.boolean "active", default: true
    t.datetime "hidden_at"
    t.integer "action_type", default: 0, null: false
    t.string "short_description"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean "published_proposal", default: false
  end

  create_table "dashboard_administrator_tasks", id: :serial, force: :cascade do |t|
    t.string "source_type"
    t.integer "source_id"
    t.integer "user_id"
    t.datetime "executed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["source_type", "source_id"], name: "index_dashboard_administrator_tasks_on_source"
    t.index ["user_id"], name: "index_dashboard_administrator_tasks_on_user_id"
  end

  create_table "dashboard_executed_actions", id: :serial, force: :cascade do |t|
    t.integer "proposal_id"
    t.integer "action_id"
    t.datetime "executed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action_id"], name: "index_proposal_action"
    t.index ["proposal_id"], name: "index_dashboard_executed_actions_on_proposal_id"
  end

  create_table "debate_translations", id: :serial, force: :cascade do |t|
    t.integer "debate_id", null: false
    t.string "locale", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "title"
    t.text "description"
    t.datetime "hidden_at"
    t.index ["debate_id"], name: "index_debate_translations_on_debate_id"
    t.index ["hidden_at"], name: "index_debate_translations_on_hidden_at"
    t.index ["locale"], name: "index_debate_translations_on_locale"
  end

  create_table "debates", id: :serial, force: :cascade do |t|
    t.integer "author_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "visit_id"
    t.datetime "hidden_at"
    t.integer "flags_count", default: 0
    t.datetime "ignored_flag_at"
    t.integer "cached_votes_total", default: 0
    t.integer "cached_votes_up", default: 0
    t.integer "cached_votes_down", default: 0
    t.integer "comments_count", default: 0
    t.datetime "confirmed_hide_at"
    t.integer "cached_anonymous_votes_total", default: 0
    t.integer "cached_votes_score", default: 0
    t.bigint "hot_score", default: 0
    t.integer "confidence_score", default: 0
    t.integer "geozone_id"
    t.tsvector "tsv"
    t.datetime "featured_at"
    t.bigint "projekt_id"
    t.string "on_behalf_of"
    t.bigint "projekt_phase_id"
    t.bigint "sentiment_id"
    t.string "video_url"
    t.index ["author_id", "hidden_at"], name: "index_debates_on_author_id_and_hidden_at"
    t.index ["author_id"], name: "index_debates_on_author_id"
    t.index ["cached_votes_down"], name: "index_debates_on_cached_votes_down"
    t.index ["cached_votes_score"], name: "index_debates_on_cached_votes_score"
    t.index ["cached_votes_total"], name: "index_debates_on_cached_votes_total"
    t.index ["cached_votes_up"], name: "index_debates_on_cached_votes_up"
    t.index ["confidence_score"], name: "index_debates_on_confidence_score"
    t.index ["geozone_id"], name: "index_debates_on_geozone_id"
    t.index ["hidden_at"], name: "index_debates_on_hidden_at"
    t.index ["hot_score"], name: "index_debates_on_hot_score"
    t.index ["projekt_id"], name: "index_debates_on_projekt_id"
    t.index ["projekt_phase_id"], name: "index_debates_on_projekt_phase_id"
    t.index ["sentiment_id"], name: "index_debates_on_sentiment_id"
    t.index ["tsv"], name: "index_debates_on_tsv", using: :gin
  end

  create_table "deficiency_report_categories", force: :cascade do |t|
    t.string "color"
    t.string "icon"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "given_order"
    t.text "warning_text", default: ""
    t.string "default_responsible_type"
    t.bigint "default_responsible_id"
    t.boolean "ai_fallback", default: false, null: false
    t.text "ai_hint"
    t.index ["default_responsible_type", "default_responsible_id"], name: "index_deficiency_report_categories_on_default_responsible"
  end

  create_table "deficiency_report_category_translations", force: :cascade do |t|
    t.bigint "deficiency_report_category_id", null: false
    t.string "locale", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name"
    t.index ["deficiency_report_category_id"], name: "index_d61b31ba5bbffdea13be0cd92b8cb671cb6d18b5"
    t.index ["locale"], name: "index_deficiency_report_category_translations_on_locale"
  end

  create_table "deficiency_report_confirmation_popup_answers", force: :cascade do |t|
    t.bigint "confirmation_popup_id", null: false
    t.string "label"
    t.integer "behavior", default: 0, null: false
    t.text "flash_notice"
    t.integer "position", default: 0, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["confirmation_popup_id"], name: "index_dr_confirmation_popup_answers_on_popup_id"
  end

  create_table "deficiency_report_confirmation_popups", force: :cascade do |t|
    t.boolean "enabled", default: false, null: false
    t.text "question"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "deficiency_report_feedback_forms", force: :cascade do |t|
    t.bigint "deficiency_report_id"
    t.integer "overall_satisfaction"
    t.integer "response_time_satisfaction"
    t.integer "communication_satisfaction"
    t.boolean "resolved"
    t.text "what_liked_note"
    t.text "what_improve_note"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["deficiency_report_id"], name: "index_deficiency_report_feedback_forms_on_deficiency_report_id"
  end

  create_table "deficiency_report_intake_channel_translations", force: :cascade do |t|
    t.bigint "deficiency_report_intake_channel_id", null: false
    t.string "locale", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "name"
    t.index ["deficiency_report_intake_channel_id"], name: "index_3ee3fbfe2e51b97debe9275dca58a65df747c9da"
    t.index ["locale"], name: "index_deficiency_report_intake_channel_translations_on_locale"
  end

  create_table "deficiency_report_intake_channels", force: :cascade do |t|
    t.integer "given_order"
    t.boolean "default", default: false, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "deficiency_report_managers", force: :cascade do |t|
    t.bigint "user_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["user_id"], name: "index_deficiency_report_managers_on_user_id"
  end

  create_table "deficiency_report_officer_group_assignments", force: :cascade do |t|
    t.bigint "deficiency_report_officer_id", null: false
    t.bigint "deficiency_report_officer_group_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["deficiency_report_officer_group_id"], name: "index_dr_officer_group_assignments_on_dr_officer_group_id"
    t.index ["deficiency_report_officer_id", "deficiency_report_officer_group_id"], name: "index_dr_officer_group_assignments_on_dro_id_and_drog_id", unique: true
    t.index ["deficiency_report_officer_id"], name: "index_dr_officer_group_assignments_on_dr_officer_id"
  end

  create_table "deficiency_report_officer_groups", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "default_email"
  end

  create_table "deficiency_report_officers", force: :cascade do |t|
    t.bigint "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "manage_all", default: false, null: false
    t.index ["user_id"], name: "index_deficiency_report_officers_on_user_id"
  end

  create_table "deficiency_report_official_answer_templates", force: :cascade do |t|
    t.string "title"
    t.text "text"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "deficiency_report_status_translations", force: :cascade do |t|
    t.bigint "deficiency_report_status_id", null: false
    t.string "locale", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "title"
    t.text "description"
    t.index ["deficiency_report_status_id"], name: "index_9003f0b89e1dd7ed97cbb6fd7a245a79809763a3"
    t.index ["locale"], name: "index_deficiency_report_status_translations_on_locale"
  end

  create_table "deficiency_report_statuses", force: :cascade do |t|
    t.string "color"
    t.string "icon"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "given_order"
    t.text "notice_text", default: ""
    t.boolean "archive_reports", default: false
    t.integer "reminder_delay"
  end

  create_table "deficiency_report_subcategories", force: :cascade do |t|
    t.bigint "deficiency_report_category_id", null: false
    t.integer "given_order"
    t.string "default_responsible_type"
    t.bigint "default_responsible_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.text "ai_hint"
    t.index ["default_responsible_type", "default_responsible_id"], name: "index_dr_subcategories_on_default_responsible"
    t.index ["deficiency_report_category_id"], name: "index_dr_subcategories_on_category_id"
  end

  create_table "deficiency_report_subcategory_translations", force: :cascade do |t|
    t.bigint "deficiency_report_subcategory_id", null: false
    t.string "locale", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "name"
    t.index ["deficiency_report_subcategory_id"], name: "index_5cceb5c9355a5d7ca9bee41d38d557369ce7db46"
    t.index ["locale"], name: "index_deficiency_report_subcategory_translations_on_locale"
  end

  create_table "deficiency_report_translations", force: :cascade do |t|
    t.bigint "deficiency_report_id", null: false
    t.string "locale", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "title"
    t.text "description"
    t.text "summary"
    t.text "official_answer"
    t.index ["deficiency_report_id"], name: "index_deficiency_report_translations_on_deficiency_report_id"
    t.index ["locale"], name: "index_deficiency_report_translations_on_locale"
  end

  create_table "deficiency_report_watches", force: :cascade do |t|
    t.bigint "deficiency_report_id", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["deficiency_report_id", "user_id"], name: "index_dr_watches_on_report_and_user", unique: true
    t.index ["user_id"], name: "index_dr_watches_on_user_id"
  end

  create_table "deficiency_reports", force: :cascade do |t|
    t.integer "author_id"
    t.integer "comments_count", default: 0
    t.string "video_url"
    t.boolean "official_answer_approved", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "deficiency_report_category_id"
    t.bigint "deficiency_report_status_id"
    t.bigint "deficiency_report_officer_id"
    t.integer "cached_votes_total", default: 0
    t.integer "cached_votes_up", default: 0
    t.integer "cached_votes_down", default: 0
    t.integer "cached_votes_score", default: 0
    t.integer "cached_anonymous_votes_total", default: 0
    t.datetime "hidden_at"
    t.tsvector "tsv"
    t.bigint "hot_score", default: 0
    t.string "on_behalf_of"
    t.datetime "assigned_at"
    t.boolean "notify_officer_about_new_comments", default: false
    t.datetime "notified_officer_about_new_comments_datetime"
    t.boolean "admin_accepted", default: false
    t.string "responsible_type"
    t.bigint "responsible_id"
    t.datetime "status_changed_at"
    t.datetime "archived_at"
    t.bigint "deficiency_report_intake_channel_id"
    t.bigint "deficiency_report_subcategory_id"
    t.bigint "recorded_by_id"
    t.index ["cached_anonymous_votes_total"], name: "index_deficiency_reports_on_cached_anonymous_votes_total"
    t.index ["cached_votes_down"], name: "index_deficiency_reports_on_cached_votes_down"
    t.index ["cached_votes_score"], name: "index_deficiency_reports_on_cached_votes_score"
    t.index ["cached_votes_total"], name: "index_deficiency_reports_on_cached_votes_total"
    t.index ["cached_votes_up"], name: "index_deficiency_reports_on_cached_votes_up"
    t.index ["deficiency_report_category_id"], name: "index_deficiency_reports_on_deficiency_report_category_id"
    t.index ["deficiency_report_intake_channel_id"], name: "index_deficiency_reports_on_intake_channel_id"
    t.index ["deficiency_report_officer_id"], name: "index_deficiency_reports_on_deficiency_report_officer_id"
    t.index ["deficiency_report_status_id"], name: "index_deficiency_reports_on_deficiency_report_status_id"
    t.index ["deficiency_report_subcategory_id"], name: "index_deficiency_reports_on_subcategory_id"
    t.index ["hidden_at"], name: "index_deficiency_reports_on_hidden_at"
    t.index ["hot_score"], name: "index_deficiency_reports_on_hot_score"
    t.index ["recorded_by_id"], name: "index_deficiency_reports_on_recorded_by_id"
    t.index ["responsible_type", "responsible_id"], name: "index_deficiency_reports_on_responsible"
    t.index ["tsv"], name: "index_deficiency_reports_on_tsv", using: :gin
  end

  create_table "delayed_jobs", id: :serial, force: :cascade do |t|
    t.integer "priority", default: 0, null: false
    t.integer "attempts", default: 0, null: false
    t.text "handler", null: false
    t.text "last_error"
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string "locked_by"
    t.string "queue"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["priority", "run_at"], name: "delayed_jobs_priority"
  end

  create_table "direct_messages", id: :serial, force: :cascade do |t|
    t.integer "sender_id"
    t.integer "receiver_id"
    t.string "title"
    t.text "body"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "documents", id: :serial, force: :cascade do |t|
    t.string "title"
    t.string "attachment_file_name"
    t.string "attachment_content_type"
    t.bigint "attachment_file_size"
    t.datetime "attachment_updated_at"
    t.integer "user_id"
    t.string "documentable_type"
    t.integer "documentable_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "admin", default: false
    t.index ["documentable_type", "documentable_id"], name: "index_documents_on_documentable_type_and_documentable_id"
    t.index ["user_id", "documentable_type", "documentable_id"], name: "access_documents"
    t.index ["user_id"], name: "index_documents_on_user_id"
  end

  create_table "email_activities", force: :cascade do |t|
    t.string "email"
    t.string "actionable_type"
    t.bigint "actionable_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["actionable_id", "actionable_type"], name: "index_email_activities_on_actionable_id_and_actionable_type"
    t.index ["actionable_type", "actionable_id"], name: "index_email_activities_on_actionable_type_and_actionable_id"
  end

  create_table "external_api_keys", force: :cascade do |t|
    t.string "service"
    t.string "name"
    t.text "value"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "failed_census_calls", id: :serial, force: :cascade do |t|
    t.integer "user_id"
    t.string "document_number"
    t.string "document_type"
    t.date "date_of_birth"
    t.string "postal_code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "district_code"
    t.integer "poll_officer_id"
    t.integer "year_of_birth"
    t.index ["poll_officer_id"], name: "index_failed_census_calls_on_poll_officer_id"
    t.index ["user_id"], name: "index_failed_census_calls_on_user_id"
  end

  create_table "flags", id: :serial, force: :cascade do |t|
    t.integer "user_id"
    t.string "flaggable_type"
    t.integer "flaggable_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["flaggable_type", "flaggable_id"], name: "index_flags_on_flaggable_type_and_flaggable_id"
    t.index ["user_id", "flaggable_type", "flaggable_id"], name: "access_inappropiate_flags"
    t.index ["user_id"], name: "index_flags_on_user_id"
  end

  create_table "follows", id: :serial, force: :cascade do |t|
    t.integer "user_id"
    t.string "followable_type"
    t.integer "followable_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["followable_type", "followable_id"], name: "index_follows_on_followable_type_and_followable_id"
    t.index ["user_id", "followable_type", "followable_id"], name: "access_follows"
    t.index ["user_id"], name: "index_follows_on_user_id"
  end

  create_table "formular_answer_documents", force: :cascade do |t|
    t.bigint "formular_answer_id"
    t.string "formular_field_key"
    t.string "title", limit: 80
    t.string "attachment_file_name"
    t.string "attachment_content_type"
    t.bigint "attachment_file_size"
    t.datetime "attachment_updated_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["formular_answer_id"], name: "index_formular_answer_documents_on_formular_answer_id"
  end

  create_table "formular_answer_images", force: :cascade do |t|
    t.bigint "formular_answer_id"
    t.string "formular_field_key"
    t.string "title", limit: 80
    t.string "attachment_file_name"
    t.string "attachment_content_type"
    t.bigint "attachment_file_size"
    t.datetime "attachment_updated_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["formular_answer_id"], name: "index_formular_answer_images_on_formular_answer_id"
  end

  create_table "formular_answers", force: :cascade do |t|
    t.jsonb "answers", default: {}, null: false
    t.bigint "formular_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "submitter_id"
    t.string "original_submitter_email"
    t.index ["formular_id"], name: "index_formular_answers_on_formular_id"
  end

  create_table "formular_fields", force: :cascade do |t|
    t.integer "given_order", default: 1
    t.boolean "required", default: false, null: false
    t.string "name"
    t.string "description"
    t.string "key"
    t.string "kind"
    t.jsonb "options", default: {}, null: false
    t.bigint "formular_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "follow_up", default: false
    t.index ["formular_id"], name: "index_formular_fields_on_formular_id"
    t.index ["key", "formular_id"], name: "index_formular_fields_on_key_and_formular_id", unique: true
    t.index ["name", "formular_id"], name: "index_formular_fields_on_name_and_formular_id", unique: true
  end

  create_table "formular_follow_up_letter_recipients", force: :cascade do |t|
    t.bigint "formular_follow_up_letter_id"
    t.bigint "formular_answer_id"
    t.string "email"
    t.string "subscription_token"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["formular_answer_id"], name: "index_recipients_on_formular_answer_id"
    t.index ["formular_follow_up_letter_id"], name: "index_recipients_on_formular_follow_up_letter_id"
  end

  create_table "formular_follow_up_letters", force: :cascade do |t|
    t.bigint "formular_id"
    t.string "subject"
    t.string "from"
    t.text "body"
    t.date "sent_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "show_follow_up_button", default: false
    t.index ["formular_id"], name: "index_formular_follow_up_letters_on_formular_id"
  end

  create_table "formulars", force: :cascade do |t|
    t.bigint "projekt_phase_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["projekt_phase_id"], name: "index_formulars_on_projekt_phase_id"
  end

  create_table "geozones", id: :serial, force: :cascade do |t|
    t.string "name"
    t.string "html_map_coordinates"
    t.string "external_code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "census_code"
    t.string "postal_codes"
  end

  create_table "geozones_polls", id: :serial, force: :cascade do |t|
    t.integer "geozone_id"
    t.integer "poll_id"
    t.index ["geozone_id"], name: "index_geozones_polls_on_geozone_id"
    t.index ["poll_id"], name: "index_geozones_polls_on_poll_id"
  end

  create_table "geozones_projekts", id: false, force: :cascade do |t|
    t.bigint "geozone_id", null: false
    t.bigint "projekt_id", null: false
    t.index ["projekt_id", "geozone_id"], name: "index_geozones_projekts_on_projekt_id_and_geozone_id", unique: true
  end

  create_table "graphql_users", force: :cascade do |t|
    t.string "auth_token"
    t.bigint "user_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["user_id"], name: "index_graphql_users_on_user_id"
  end

  create_table "i18n_content_translations", id: :serial, force: :cascade do |t|
    t.integer "i18n_content_id", null: false
    t.string "locale", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "value"
    t.index ["i18n_content_id"], name: "index_i18n_content_translations_on_i18n_content_id"
    t.index ["locale"], name: "index_i18n_content_translations_on_locale"
  end

  create_table "i18n_contents", id: :serial, force: :cascade do |t|
    t.string "key"
  end

  create_table "idea_categories", force: :cascade do |t|
    t.string "color"
    t.string "icon"
    t.integer "given_order"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.bigint "idea_officer_id"
    t.index ["idea_officer_id"], name: "index_idea_categories_on_idea_officer_id"
  end

  create_table "idea_category_translations", force: :cascade do |t|
    t.bigint "idea_category_id", null: false
    t.string "locale", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "name"
    t.index ["idea_category_id"], name: "index_idea_category_translations_on_idea_category_id"
    t.index ["locale"], name: "index_idea_category_translations_on_locale"
  end

  create_table "idea_managers", force: :cascade do |t|
    t.bigint "user_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["user_id"], name: "index_idea_managers_on_user_id"
  end

  create_table "idea_officers", force: :cascade do |t|
    t.bigint "user_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.boolean "manage_all", default: false, null: false
    t.index ["user_id"], name: "index_idea_officers_on_user_id"
  end

  create_table "idea_translations", force: :cascade do |t|
    t.bigint "idea_id", null: false
    t.string "locale", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "title"
    t.text "description"
    t.text "official_answer"
    t.index ["idea_id"], name: "index_idea_translations_on_idea_id"
    t.index ["locale"], name: "index_idea_translations_on_locale"
  end

  create_table "ideas", force: :cascade do |t|
    t.bigint "author_id", null: false
    t.string "video_url"
    t.datetime "hidden_at"
    t.tsvector "tsv"
    t.string "on_behalf_of"
    t.integer "comments_count", default: 0
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "cached_votes_up", default: 0
    t.bigint "idea_category_id"
    t.integer "votes_needed_for_success", default: 100, null: false
    t.integer "timeframe", default: 50, null: false
    t.bigint "idea_officer_id"
    t.datetime "admin_accepted_at"
    t.index ["author_id"], name: "index_ideas_on_author_id"
    t.index ["idea_category_id"], name: "index_ideas_on_idea_category_id"
    t.index ["idea_officer_id"], name: "index_ideas_on_idea_officer_id"
    t.index ["tsv"], name: "index_ideas_on_tsv", using: :gin
  end

  create_table "identities", id: :serial, force: :cascade do |t|
    t.integer "user_id"
    t.string "provider"
    t.string "uid"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "auth_data", default: ""
    t.index ["user_id"], name: "index_identities_on_user_id"
  end

  create_table "images", id: :serial, force: :cascade do |t|
    t.string "imageable_type"
    t.integer "imageable_id"
    t.string "title", limit: 80
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "attachment_file_name"
    t.string "attachment_content_type"
    t.bigint "attachment_file_size"
    t.datetime "attachment_updated_at"
    t.integer "user_id"
    t.boolean "concealed", default: false
    t.string "credits"
    t.boolean "admin", default: false, null: false
    t.boolean "ai_generated", default: false, null: false
    t.boolean "ai_generated_in_app", default: false, null: false
    t.index ["imageable_type", "imageable_id"], name: "index_images_on_imageable_type_and_imageable_id"
    t.index ["user_id"], name: "index_images_on_user_id"
  end

  create_table "individual_group_values", force: :cascade do |t|
    t.string "name"
    t.bigint "individual_group_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "email_pattern", default: "", null: false
    t.text "auto_join_emails", default: [], array: true
    t.index ["individual_group_id"], name: "index_individual_group_values_on_individual_group_id"
  end

  create_table "individual_group_values_projekt_phases", id: false, force: :cascade do |t|
    t.bigint "individual_group_value_id", null: false
    t.bigint "projekt_phase_id", null: false
    t.index ["individual_group_value_id", "projekt_phase_id"], name: "idx_igv_projekt_phases_on_value_id_and_phase_id"
    t.index ["projekt_phase_id", "individual_group_value_id"], name: "idx_igv_projekt_phases_on_phase_id_and_value_id"
  end

  create_table "individual_group_values_projekts", id: false, force: :cascade do |t|
    t.bigint "individual_group_value_id", null: false
    t.bigint "projekt_id", null: false
    t.index ["individual_group_value_id", "projekt_id"], name: "idx_igv_projekts_on_value_id_and_projekt_id"
    t.index ["projekt_id", "individual_group_value_id"], name: "idx_igv_projekts_on_projekt_id_and_value_id"
  end

  create_table "individual_groups", force: :cascade do |t|
    t.string "name"
    t.integer "kind", default: 0
    t.boolean "visible", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "internal_api_clients", force: :cascade do |t|
    t.string "name"
    t.integer "registration_status"
    t.string "auth_token"
    t.string "domain"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "service_api_token"
    t.index ["service_api_token"], name: "index_internal_api_clients_on_service_api_token"
  end

  create_table "landing_page_manager_assignments", force: :cascade do |t|
    t.bigint "landing_page_manager_id"
    t.bigint "page_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["landing_page_manager_id"], name: "idx_lpm_assignments_on_manager_id"
    t.index ["page_id"], name: "idx_lpm_assignments_on_page_id"
  end

  create_table "landing_page_managers", force: :cascade do |t|
    t.bigint "user_id"
    t.boolean "manage_all_landing_pages", default: false, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["user_id"], name: "index_landing_page_managers_on_user_id"
  end

  create_table "legislation_annotations", id: :serial, force: :cascade do |t|
    t.string "quote"
    t.text "ranges"
    t.text "text"
    t.integer "legislation_draft_version_id"
    t.integer "author_id"
    t.datetime "hidden_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "comments_count", default: 0
    t.string "range_start"
    t.integer "range_start_offset"
    t.string "range_end"
    t.integer "range_end_offset"
    t.text "context"
    t.index ["author_id"], name: "index_legislation_annotations_on_author_id"
    t.index ["hidden_at"], name: "index_legislation_annotations_on_hidden_at"
    t.index ["legislation_draft_version_id"], name: "index_legislation_annotations_on_legislation_draft_version_id"
    t.index ["range_start", "range_end"], name: "index_legislation_annotations_on_range_start_and_range_end"
  end

  create_table "legislation_answers", id: :serial, force: :cascade do |t|
    t.integer "legislation_question_id"
    t.integer "legislation_question_option_id"
    t.integer "user_id"
    t.datetime "hidden_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["hidden_at"], name: "index_legislation_answers_on_hidden_at"
    t.index ["legislation_question_id"], name: "index_legislation_answers_on_legislation_question_id"
    t.index ["legislation_question_option_id"], name: "index_legislation_answers_on_legislation_question_option_id"
    t.index ["user_id"], name: "index_legislation_answers_on_user_id"
  end

  create_table "legislation_draft_version_translations", id: :serial, force: :cascade do |t|
    t.integer "legislation_draft_version_id", null: false
    t.string "locale", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "title"
    t.text "changelog"
    t.text "body"
    t.datetime "hidden_at"
    t.index ["hidden_at"], name: "index_legislation_draft_version_translations_on_hidden_at"
    t.index ["legislation_draft_version_id"], name: "index_900e5ba94457606e69e89193db426e8ddff809bc"
    t.index ["locale"], name: "index_legislation_draft_version_translations_on_locale"
  end

  create_table "legislation_draft_versions", id: :serial, force: :cascade do |t|
    t.integer "legislation_process_id"
    t.string "status", default: "draft"
    t.boolean "final_version", default: false
    t.datetime "hidden_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["hidden_at"], name: "index_legislation_draft_versions_on_hidden_at"
    t.index ["legislation_process_id"], name: "index_legislation_draft_versions_on_legislation_process_id"
    t.index ["status"], name: "index_legislation_draft_versions_on_status"
  end

  create_table "legislation_process_translations", id: :serial, force: :cascade do |t|
    t.integer "legislation_process_id", null: false
    t.string "locale", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "title"
    t.text "summary"
    t.text "description"
    t.text "additional_info"
    t.text "milestones_summary"
    t.text "homepage"
    t.datetime "hidden_at"
    t.index ["hidden_at"], name: "index_legislation_process_translations_on_hidden_at"
    t.index ["legislation_process_id"], name: "index_199e5fed0aca73302243f6a1fca885ce10cdbb55"
    t.index ["locale"], name: "index_legislation_process_translations_on_locale"
  end

  create_table "legislation_processes", id: :serial, force: :cascade do |t|
    t.date "start_date"
    t.date "end_date"
    t.date "debate_start_date"
    t.date "debate_end_date"
    t.date "draft_publication_date"
    t.date "allegations_start_date"
    t.date "allegations_end_date"
    t.date "result_publication_date"
    t.datetime "hidden_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "debate_phase_enabled", default: false
    t.boolean "allegations_phase_enabled", default: false
    t.boolean "draft_publication_enabled", default: false
    t.boolean "result_publication_enabled", default: false
    t.boolean "published", default: true
    t.date "proposals_phase_start_date"
    t.date "proposals_phase_end_date"
    t.boolean "proposals_phase_enabled"
    t.text "proposals_description"
    t.date "draft_start_date"
    t.date "draft_end_date"
    t.boolean "draft_phase_enabled", default: false
    t.boolean "homepage_enabled", default: false
    t.text "background_color"
    t.text "font_color"
    t.tsvector "tsv"
    t.bigint "projekt_id"
    t.bigint "projekt_phase_id"
    t.index ["allegations_end_date"], name: "index_legislation_processes_on_allegations_end_date"
    t.index ["allegations_start_date"], name: "index_legislation_processes_on_allegations_start_date"
    t.index ["debate_end_date"], name: "index_legislation_processes_on_debate_end_date"
    t.index ["debate_start_date"], name: "index_legislation_processes_on_debate_start_date"
    t.index ["draft_end_date"], name: "index_legislation_processes_on_draft_end_date"
    t.index ["draft_publication_date"], name: "index_legislation_processes_on_draft_publication_date"
    t.index ["draft_start_date"], name: "index_legislation_processes_on_draft_start_date"
    t.index ["end_date"], name: "index_legislation_processes_on_end_date"
    t.index ["hidden_at"], name: "index_legislation_processes_on_hidden_at"
    t.index ["projekt_id"], name: "index_legislation_processes_on_projekt_id"
    t.index ["projekt_phase_id"], name: "index_legislation_processes_on_projekt_phase_id"
    t.index ["result_publication_date"], name: "index_legislation_processes_on_result_publication_date"
    t.index ["start_date"], name: "index_legislation_processes_on_start_date"
  end

  create_table "legislation_proposals", id: :serial, force: :cascade do |t|
    t.integer "legislation_process_id"
    t.string "title", limit: 80
    t.text "description"
    t.integer "author_id"
    t.datetime "hidden_at"
    t.integer "flags_count", default: 0
    t.datetime "ignored_flag_at"
    t.integer "cached_votes_up", default: 0
    t.integer "comments_count", default: 0
    t.datetime "confirmed_hide_at"
    t.bigint "hot_score", default: 0
    t.integer "confidence_score", default: 0
    t.string "responsible_name", limit: 60
    t.text "summary"
    t.string "video_url"
    t.tsvector "tsv"
    t.integer "geozone_id"
    t.datetime "retired_at"
    t.string "retired_reason"
    t.text "retired_explanation"
    t.integer "community_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "cached_votes_total", default: 0
    t.integer "cached_votes_down", default: 0
    t.boolean "selected"
    t.integer "cached_votes_score", default: 0
    t.index ["cached_votes_score"], name: "index_legislation_proposals_on_cached_votes_score"
    t.index ["legislation_process_id"], name: "index_legislation_proposals_on_legislation_process_id"
  end

  create_table "legislation_question_option_translations", id: :serial, force: :cascade do |t|
    t.integer "legislation_question_option_id", null: false
    t.string "locale", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "value"
    t.datetime "hidden_at"
    t.index ["hidden_at"], name: "index_legislation_question_option_translations_on_hidden_at"
    t.index ["legislation_question_option_id"], name: "index_61bcec8729110b7f8e1e9e5ce08780878597a209"
    t.index ["locale"], name: "index_legislation_question_option_translations_on_locale"
  end

  create_table "legislation_question_options", id: :serial, force: :cascade do |t|
    t.integer "legislation_question_id"
    t.integer "answers_count", default: 0
    t.datetime "hidden_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["hidden_at"], name: "index_legislation_question_options_on_hidden_at"
    t.index ["legislation_question_id"], name: "index_legislation_question_options_on_legislation_question_id"
  end

  create_table "legislation_question_translations", id: :serial, force: :cascade do |t|
    t.integer "legislation_question_id", null: false
    t.string "locale", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "title"
    t.datetime "hidden_at"
    t.index ["hidden_at"], name: "index_legislation_question_translations_on_hidden_at"
    t.index ["legislation_question_id"], name: "index_d34cc1e1fe6d5162210c41ce56533c5afabcdbd3"
    t.index ["locale"], name: "index_legislation_question_translations_on_locale"
  end

  create_table "legislation_questions", id: :serial, force: :cascade do |t|
    t.integer "legislation_process_id"
    t.integer "answers_count", default: 0
    t.datetime "hidden_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "comments_count", default: 0
    t.integer "author_id"
    t.index ["hidden_at"], name: "index_legislation_questions_on_hidden_at"
    t.index ["legislation_process_id"], name: "index_legislation_questions_on_legislation_process_id"
  end

  create_table "links", id: :serial, force: :cascade do |t|
    t.string "label"
    t.string "url"
    t.string "linkable_type"
    t.integer "linkable_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["linkable_type", "linkable_id"], name: "index_links_on_linkable_type_and_linkable_id"
  end

  create_table "local_census_records", id: :serial, force: :cascade do |t|
    t.string "document_number", null: false
    t.string "document_type", null: false
    t.date "date_of_birth", null: false
    t.string "postal_code", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["document_number", "document_type"], name: "index_local_census_records_on_document_number_and_document_type", unique: true
    t.index ["document_number"], name: "index_local_census_records_on_document_number"
  end

  create_table "locks", id: :serial, force: :cascade do |t|
    t.integer "user_id"
    t.integer "tries", default: 0
    t.datetime "locked_until", default: "2000-01-01 01:01:01", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_locks_on_user_id"
  end

  create_table "machine_learning_infos", force: :cascade do |t|
    t.string "kind"
    t.datetime "generated_at"
    t.string "script"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "machine_learning_jobs", force: :cascade do |t|
    t.datetime "started_at"
    t.datetime "finished_at"
    t.string "script"
    t.integer "pid"
    t.string "error"
    t.bigint "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_machine_learning_jobs_on_user_id"
  end

  create_table "managers", id: :serial, force: :cascade do |t|
    t.integer "user_id"
    t.index ["user_id"], name: "index_managers_on_user_id"
  end

  create_table "map_layers", force: :cascade do |t|
    t.string "name"
    t.string "provider"
    t.string "attribution"
    t.string "layer_names"
    t.boolean "base"
    t.bigint "projekt_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "show_by_default", default: false
    t.boolean "transparent", default: false
    t.integer "protocol", default: 1
    t.string "mappable_type"
    t.bigint "mappable_id"
    t.decimal "opacity", precision: 2, scale: 1, default: "1.0"
    t.jsonb "config", default: {}, null: false
    t.string "layer_defs"
    t.index ["mappable_type", "mappable_id"], name: "index_map_layers_on_mappable_type_and_mappable_id"
    t.index ["projekt_id"], name: "index_map_layers_on_projekt_id"
  end

  create_table "map_locations", id: :serial, force: :cascade do |t|
    t.float "latitude"
    t.float "longitude"
    t.integer "zoom"
    t.string "pin_color"
    t.jsonb "features", default: {}, null: false
    t.boolean "show_admin_shape", default: false
    t.float "altitude"
    t.jsonb "geocoder_data", default: {}
    t.string "approximated_address"
    t.string "mappable_type"
    t.bigint "mappable_id"
    t.integer "rendering_library", null: false
    t.jsonb "features_bu", default: {}, null: false
    t.boolean "default", default: false, null: false
    t.bigint "registered_address_district_id"
    t.string "polygon_color", default: "#008000"
    t.string "mapbox_style_id"
    t.index ["features"], name: "index_map_locations_on_features", using: :gin
    t.index ["mappable_type", "mappable_id"], name: "index_map_locations_on_mappable"
    t.index ["registered_address_district_id"], name: "index_map_locations_on_registered_address_district_id"
  end

  create_table "masterportal_collections", force: :cascade do |t|
    t.bigint "projekt_phase_id", null: false
    t.string "collection_id", null: false
    t.string "name"
    t.string "endpoint_url"
    t.boolean "create_domain_records", default: false, null: false
    t.string "import_status", default: "pending", null: false
    t.text "import_error"
    t.datetime "last_imported_at"
    t.integer "last_imported_count", default: 0, null: false
    t.string "destroy_status"
    t.text "destroy_error"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "source", default: "geoserver", null: false
    t.string "icon_url"
    t.string "feature_color"
    t.boolean "contains_shapes", default: false, null: false
    t.boolean "has_default_icon_pins", default: false, null: false
    t.index ["projekt_phase_id", "collection_id"], name: "index_masterportal_collections_on_phase_and_collection_id", unique: true
    t.index ["projekt_phase_id"], name: "index_masterportal_collections_on_projekt_phase_id"
  end

  create_table "masterportal_pins", force: :cascade do |t|
    t.bigint "projekt_phase_id", null: false
    t.string "endpoint_url", null: false
    t.string "collection_id", null: false
    t.string "external_id", null: false
    t.string "title"
    t.text "description"
    t.decimal "latitude", precision: 10, scale: 7, null: false
    t.decimal "longitude", precision: 10, scale: 7, null: false
    t.jsonb "properties", default: {}, null: false
    t.jsonb "raw_feature"
    t.datetime "last_imported_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "collection_title"
    t.bigint "masterportal_collection_id"
    t.jsonb "geometry"
    t.index "((properties)::text) gin_trgm_ops", name: "index_masterportal_pins_on_properties_text_trgm", using: :gin
    t.index ["collection_id"], name: "index_masterportal_pins_on_collection_id_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["description"], name: "index_masterportal_pins_on_description_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["external_id"], name: "index_masterportal_pins_on_external_id_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["masterportal_collection_id"], name: "index_masterportal_pins_on_masterportal_collection_id"
    t.index ["projekt_phase_id", "collection_id"], name: "index_masterportal_pins_on_phase_and_collection_id"
    t.index ["projekt_phase_id", "external_id"], name: "index_masterportal_pins_on_phase_and_external_id", unique: true
    t.index ["projekt_phase_id"], name: "index_masterportal_pins_on_projekt_phase_id"
    t.index ["title"], name: "index_masterportal_pins_on_title_trgm", opclass: :gin_trgm_ops, using: :gin
  end

  create_table "memos", force: :cascade do |t|
    t.string "memoable_type"
    t.bigint "memoable_id"
    t.bigint "user_id"
    t.text "text"
    t.datetime "hidden_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "ancestry"
    t.datetime "last_notification_sent_at"
    t.index ["ancestry"], name: "index_memos_on_ancestry"
    t.index ["hidden_at"], name: "index_memos_on_hidden_at"
    t.index ["memoable_id", "memoable_type"], name: "index_memos_on_memoable_id_and_memoable_type"
    t.index ["memoable_type", "memoable_id"], name: "index_memos_on_memoable"
    t.index ["user_id"], name: "index_memos_on_user_id"
  end

  create_table "milestone_statuses", id: :serial, force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.datetime "hidden_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["hidden_at"], name: "index_milestone_statuses_on_hidden_at"
  end

  create_table "milestone_translations", id: :serial, force: :cascade do |t|
    t.integer "milestone_id", null: false
    t.string "locale", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "title"
    t.text "description"
    t.string "custom_date"
    t.index ["locale"], name: "index_milestone_translations_on_locale"
    t.index ["milestone_id"], name: "index_milestone_translations_on_milestone_id"
  end

  create_table "milestones", id: :serial, force: :cascade do |t|
    t.string "milestoneable_type"
    t.integer "milestoneable_id"
    t.datetime "publication_date"
    t.integer "status_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["status_id"], name: "index_milestones_on_status_id"
  end

  create_table "ml_summary_comments", force: :cascade do |t|
    t.integer "commentable_id"
    t.string "commentable_type"
    t.text "body"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "modal_notification_translations", force: :cascade do |t|
    t.bigint "modal_notification_id", null: false
    t.string "locale", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "title"
    t.text "html_content"
    t.index ["locale"], name: "index_modal_notification_translations_on_locale"
    t.index ["modal_notification_id"], name: "index_modal_notification_translations_on_modal_notification_id"
  end

  create_table "modal_notifications", force: :cascade do |t|
    t.date "active_from"
    t.date "active_to"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "moderators", id: :serial, force: :cascade do |t|
    t.integer "user_id"
    t.index ["user_id"], name: "index_moderators_on_user_id"
  end

  create_table "navbar_items", force: :cascade do |t|
    t.integer "kind"
    t.string "preset"
    t.bigint "projekt_id"
    t.string "external_url"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.bigint "parent_id"
    t.integer "position", default: 0, null: false
    t.integer "landing_page_id"
    t.string "custom_title"
    t.boolean "open_in_new_tab", default: false, null: false
    t.integer "linked_page_id"
    t.index ["landing_page_id"], name: "index_navbar_items_on_landing_page_id"
    t.index ["linked_page_id"], name: "index_navbar_items_on_linked_page_id"
    t.index ["parent_id"], name: "index_navbar_items_on_parent_id"
    t.index ["projekt_id"], name: "index_navbar_items_on_projekt_id"
  end

  create_table "newsletters", id: :serial, force: :cascade do |t|
    t.string "subject"
    t.string "segment_recipient"
    t.string "from"
    t.text "body"
    t.date "sent_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "hidden_at"
    t.string "title"
    t.text "subtitle"
    t.string "greeting"
    t.bigint "recipient_group_id"
    t.string "title_color", default: "#000000", null: false
    t.string "subtitle_color", default: "#000000", null: false
    t.boolean "respect_newsletter_optout", default: true, null: false
    t.index ["recipient_group_id"], name: "index_newsletters_on_recipient_group_id"
  end

  create_table "notifications", id: :serial, force: :cascade do |t|
    t.integer "user_id"
    t.string "notifiable_type"
    t.integer "notifiable_id"
    t.integer "counter", default: 1
    t.datetime "emailed_at"
    t.datetime "read_at"
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "officing_manager_assignments", force: :cascade do |t|
    t.bigint "officing_manager_id", null: false
    t.bigint "projekt_phase_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["officing_manager_id", "projekt_phase_id"], name: "index_om_assignments_on_om_id_and_projekt_phase_id", unique: true
    t.index ["officing_manager_id"], name: "index_officing_manager_assignments_on_officing_manager_id"
    t.index ["projekt_phase_id"], name: "index_officing_manager_assignments_on_projekt_phase_id"
  end

  create_table "officing_managers", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["user_id"], name: "index_officing_managers_on_user_id"
  end

  create_table "ogc_import_runs", force: :cascade do |t|
    t.string "endpoint", null: false
    t.string "collection", null: false
    t.string "target_kind", null: false
    t.bigint "projekt_phase_id", null: false
    t.string "status", default: "pending", null: false
    t.integer "total_features"
    t.integer "count_created", default: 0, null: false
    t.integer "count_updated", default: 0, null: false
    t.text "error_message"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["projekt_phase_id", "created_at"], name: "index_ogc_import_runs_on_projekt_phase_and_created_at"
    t.index ["projekt_phase_id"], name: "index_ogc_import_runs_on_projekt_phase_id"
  end

  create_table "organizations", id: :serial, force: :cascade do |t|
    t.integer "user_id"
    t.string "name", limit: 60
    t.datetime "verified_at"
    t.datetime "rejected_at"
    t.string "responsible_name", limit: 60
    t.index ["user_id"], name: "index_organizations_on_user_id"
  end

  create_table "pending_role_assignments", force: :cascade do |t|
    t.string "email", null: false
    t.string "role_type", null: false
    t.jsonb "metadata", default: {}
    t.bigint "created_by_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "invitation_token"
    t.index ["email", "role_type"], name: "index_pending_role_assignments_on_email_and_role_type", unique: true
    t.index ["email"], name: "index_pending_role_assignments_on_email"
    t.index ["invitation_token"], name: "index_pending_role_assignments_on_invitation_token", unique: true, where: "(invitation_token IS NOT NULL)"
    t.index ["role_type"], name: "index_pending_role_assignments_on_role_type"
  end

  create_table "poll_answer_map_points", force: :cascade do |t|
    t.bigint "poll_answer_id", null: false
    t.float "latitude", null: false
    t.float "longitude", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["poll_answer_id"], name: "index_poll_answer_map_points_on_poll_answer_id"
  end

  create_table "poll_answers", id: :serial, force: :cascade do |t|
    t.integer "question_id"
    t.integer "author_id"
    t.string "answer"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "open_answer_text"
    t.integer "answer_weight", default: 1
    t.bigint "officing_manager_id"
    t.index ["author_id"], name: "index_poll_answers_on_author_id"
    t.index ["officing_manager_id"], name: "index_poll_answers_on_officing_manager_id"
    t.index ["question_id", "answer"], name: "index_poll_answers_on_question_id_and_answer"
    t.index ["question_id", "author_id"], name: "index_poll_answers_unique_map_point_answer", unique: true, where: "(answer IS NULL)"
    t.index ["question_id"], name: "index_poll_answers_on_question_id"
  end

  create_table "poll_ballot_sheets", id: :serial, force: :cascade do |t|
    t.text "data"
    t.integer "poll_id"
    t.integer "officer_assignment_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["officer_assignment_id"], name: "index_poll_ballot_sheets_on_officer_assignment_id"
    t.index ["poll_id"], name: "index_poll_ballot_sheets_on_poll_id"
  end

  create_table "poll_ballots", id: :serial, force: :cascade do |t|
    t.integer "ballot_sheet_id"
    t.text "data"
    t.integer "external_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "poll_booth_assignments", id: :serial, force: :cascade do |t|
    t.integer "booth_id"
    t.integer "poll_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["booth_id"], name: "index_poll_booth_assignments_on_booth_id"
    t.index ["poll_id"], name: "index_poll_booth_assignments_on_poll_id"
  end

  create_table "poll_booths", id: :serial, force: :cascade do |t|
    t.string "name"
    t.string "location"
  end

  create_table "poll_officer_assignments", id: :serial, force: :cascade do |t|
    t.integer "booth_assignment_id"
    t.integer "officer_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "date", null: false
    t.boolean "final", default: false
    t.string "user_data_log", default: ""
    t.index ["booth_assignment_id"], name: "index_poll_officer_assignments_on_booth_assignment_id"
    t.index ["officer_id"], name: "index_poll_officer_assignments_on_officer_id"
  end

  create_table "poll_officers", id: :serial, force: :cascade do |t|
    t.integer "user_id"
    t.integer "failed_census_calls_count", default: 0
    t.index ["user_id"], name: "index_poll_officers_on_user_id"
  end

  create_table "poll_partial_results", id: :serial, force: :cascade do |t|
    t.integer "question_id"
    t.integer "author_id"
    t.string "answer"
    t.integer "amount"
    t.string "origin"
    t.date "date"
    t.integer "booth_assignment_id"
    t.integer "officer_assignment_id"
    t.text "amount_log", default: ""
    t.text "officer_assignment_id_log", default: ""
    t.text "author_id_log", default: ""
    t.index ["answer"], name: "index_poll_partial_results_on_answer"
    t.index ["author_id"], name: "index_poll_partial_results_on_author_id"
    t.index ["booth_assignment_id", "date"], name: "index_poll_partial_results_on_booth_assignment_id_and_date"
    t.index ["origin"], name: "index_poll_partial_results_on_origin"
    t.index ["question_id"], name: "index_poll_partial_results_on_question_id"
  end

  create_table "poll_question_answer_translations", id: :serial, force: :cascade do |t|
    t.integer "poll_question_answer_id", null: false
    t.string "locale", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "title"
    t.text "description"
    t.index ["locale"], name: "index_poll_question_answer_translations_on_locale"
    t.index ["poll_question_answer_id"], name: "index_85270fa85f62081a3a227186b4c95fe4f7fa94b9"
  end

  create_table "poll_question_answer_videos", id: :serial, force: :cascade do |t|
    t.string "title"
    t.string "url"
    t.integer "answer_id"
    t.index ["answer_id"], name: "index_poll_question_answer_videos_on_answer_id"
  end

  create_table "poll_question_answers", id: :serial, force: :cascade do |t|
    t.integer "question_id"
    t.integer "given_order", default: 1
    t.boolean "most_voted", default: false
    t.boolean "open_answer", default: false
    t.string "more_info_link"
    t.integer "next_question_id"
    t.string "more_info_iframe"
    t.boolean "terminates_poll", default: false, null: false
    t.index ["question_id"], name: "index_poll_question_answers_on_question_id"
  end

  create_table "poll_question_imports", force: :cascade do |t|
    t.integer "projekt_phase_id"
    t.integer "author_id"
    t.text "extracted_text"
    t.string "content_locale"
    t.string "status", default: "pending", null: false
    t.jsonb "result"
    t.jsonb "created_question_ids", default: []
    t.text "error_message"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["author_id"], name: "index_poll_question_imports_on_author_id"
    t.index ["projekt_phase_id", "status"], name: "index_poll_question_imports_on_projekt_phase_id_and_status"
  end

  create_table "poll_question_translations", id: :serial, force: :cascade do |t|
    t.integer "poll_question_id", null: false
    t.string "locale", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "title"
    t.datetime "hidden_at"
    t.text "description"
    t.string "min_rating_scale_label"
    t.string "max_rating_scale_label"
    t.text "intro"
    t.index ["hidden_at"], name: "index_poll_question_translations_on_hidden_at"
    t.index ["locale"], name: "index_poll_question_translations_on_locale"
    t.index ["poll_question_id"], name: "index_poll_question_translations_on_poll_question_id"
  end

  create_table "poll_questions", id: :serial, force: :cascade do |t|
    t.integer "proposal_id"
    t.integer "poll_id"
    t.integer "author_id"
    t.string "author_visible_name"
    t.integer "comments_count"
    t.datetime "hidden_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.tsvector "tsv"
    t.string "video_url"
    t.boolean "show_images", default: false
    t.boolean "multiple", default: false
    t.integer "given_order"
    t.integer "parent_question_id"
    t.boolean "bundle_question", default: false
    t.integer "next_question_id"
    t.boolean "answer_mandatory", default: false
    t.bigint "contextualize_by_poll_question_id"
    t.bigint "contexted_clone_of_poll_question_id"
    t.bigint "context_id"
    t.boolean "randomize_answers", default: false, null: false
    t.boolean "randomize_position", default: false, null: false
    t.index ["author_id"], name: "index_poll_questions_on_author_id"
    t.index ["context_id"], name: "index_poll_questions_on_context_id"
    t.index ["contexted_clone_of_poll_question_id"], name: "index_poll_questions_on_contexted_clone_of_poll_question_id"
    t.index ["contextualize_by_poll_question_id"], name: "index_poll_questions_on_contextualize_by_poll_question_id"
    t.index ["next_question_id"], name: "index_poll_questions_on_next_question_id"
    t.index ["parent_question_id"], name: "index_poll_questions_on_parent_question_id"
    t.index ["poll_id"], name: "index_poll_questions_on_poll_id"
    t.index ["proposal_id"], name: "index_poll_questions_on_proposal_id"
    t.index ["tsv"], name: "index_poll_questions_on_tsv", using: :gin
  end

  create_table "poll_recounts", id: :serial, force: :cascade do |t|
    t.integer "author_id"
    t.string "origin"
    t.date "date"
    t.integer "booth_assignment_id"
    t.integer "officer_assignment_id"
    t.text "officer_assignment_id_log", default: ""
    t.text "author_id_log", default: ""
    t.integer "white_amount", default: 0
    t.text "white_amount_log", default: ""
    t.integer "null_amount", default: 0
    t.text "null_amount_log", default: ""
    t.integer "total_amount", default: 0
    t.text "total_amount_log", default: ""
    t.index ["booth_assignment_id"], name: "index_poll_recounts_on_booth_assignment_id"
    t.index ["officer_assignment_id"], name: "index_poll_recounts_on_officer_assignment_id"
  end

  create_table "poll_shifts", id: :serial, force: :cascade do |t|
    t.integer "booth_id"
    t.integer "officer_id"
    t.date "date"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "officer_name"
    t.string "officer_email"
    t.integer "task", default: 0, null: false
    t.index ["booth_id", "officer_id", "date", "task"], name: "index_poll_shifts_on_booth_id_and_officer_id_and_date_and_task", unique: true
    t.index ["booth_id"], name: "index_poll_shifts_on_booth_id"
    t.index ["officer_id"], name: "index_poll_shifts_on_officer_id"
  end

  create_table "poll_translations", id: :serial, force: :cascade do |t|
    t.integer "poll_id", null: false
    t.string "locale", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name"
    t.text "summary"
    t.text "description"
    t.datetime "hidden_at"
    t.text "closing_note"
    t.index ["hidden_at"], name: "index_poll_translations_on_hidden_at"
    t.index ["locale"], name: "index_poll_translations_on_locale"
    t.index ["poll_id"], name: "index_poll_translations_on_poll_id"
  end

  create_table "poll_voters", id: :serial, force: :cascade do |t|
    t.string "document_number"
    t.string "document_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "poll_id", null: false
    t.integer "booth_assignment_id"
    t.integer "age"
    t.string "gender"
    t.integer "geozone_id"
    t.integer "answer_id"
    t.integer "officer_assignment_id"
    t.integer "user_id"
    t.string "origin"
    t.integer "officer_id"
    t.string "token"
    t.bigint "officing_manager_id"
    t.index ["booth_assignment_id"], name: "index_poll_voters_on_booth_assignment_id"
    t.index ["document_number"], name: "index_poll_voters_on_document_number"
    t.index ["officer_assignment_id"], name: "index_poll_voters_on_officer_assignment_id"
    t.index ["officing_manager_id"], name: "index_poll_voters_on_officing_manager_id"
    t.index ["poll_id", "document_number", "document_type"], name: "doc_by_poll"
    t.index ["poll_id"], name: "index_poll_voters_on_poll_id"
    t.index ["user_id"], name: "index_poll_voters_on_user_id"
  end

  create_table "polls", id: :serial, force: :cascade do |t|
    t.datetime "starts_at"
    t.datetime "ends_at"
    t.boolean "published", default: false
    t.boolean "geozone_restricted", default: false
    t.integer "comments_count", default: 0
    t.integer "author_id"
    t.datetime "hidden_at"
    t.string "slug"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "budget_id"
    t.string "related_type"
    t.integer "related_id"
    t.tsvector "tsv"
    t.bigint "projekt_id"
    t.boolean "show_open_answer_author_name"
    t.boolean "show_summary_instead_of_questions", default: false
    t.boolean "show_on_home_page", default: true
    t.boolean "show_on_index_page", default: true
    t.bigint "projekt_phase_id"
    t.boolean "wizard_mode", default: false
    t.jsonb "ai_stats", default: {}
    t.string "ai_stats_refresh_status"
    t.datetime "ai_stats_refreshed_at"
    t.boolean "live", default: true, null: false
    t.index ["budget_id"], name: "index_polls_on_budget_id", unique: true
    t.index ["geozone_restricted"], name: "index_polls_on_geozone_restricted"
    t.index ["projekt_id"], name: "index_polls_on_projekt_id"
    t.index ["projekt_phase_id"], name: "index_polls_on_projekt_phase_id"
    t.index ["related_type", "related_id"], name: "index_polls_on_related_type_and_related_id"
    t.index ["starts_at", "ends_at"], name: "index_polls_on_starts_at_and_ends_at"
  end

  create_table "progress_bar_translations", id: :serial, force: :cascade do |t|
    t.integer "progress_bar_id", null: false
    t.string "locale", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "title"
    t.index ["locale"], name: "index_progress_bar_translations_on_locale"
    t.index ["progress_bar_id"], name: "index_progress_bar_translations_on_progress_bar_id"
  end

  create_table "progress_bars", id: :serial, force: :cascade do |t|
    t.integer "kind"
    t.integer "percentage"
    t.string "progressable_type"
    t.integer "progressable_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "projekt_arguments", force: :cascade do |t|
    t.string "name"
    t.string "party"
    t.boolean "pro"
    t.string "position"
    t.text "note"
    t.integer "projekt_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "projekt_phase_id"
    t.index ["projekt_id"], name: "index_projekt_arguments_on_projekt_id"
    t.index ["projekt_phase_id"], name: "index_projekt_arguments_on_projekt_phase_id"
  end

  create_table "projekt_evaluations", force: :cascade do |t|
    t.bigint "projekt_id", null: false
    t.jsonb "data", default: {}
    t.jsonb "selected_question_ids", default: []
    t.datetime "generated_at"
    t.string "status", default: "pending", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["projekt_id"], name: "index_projekt_evaluations_on_projekt_id"
    t.index ["status"], name: "index_projekt_evaluations_on_status"
  end

  create_table "projekt_event_registrations", force: :cascade do |t|
    t.bigint "projekt_event_id", null: false
    t.bigint "user_id"
    t.string "first_name"
    t.string "last_name"
    t.string "email"
    t.string "status", default: "confirmed", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.index ["confirmation_token"], name: "index_projekt_event_registrations_on_confirmation_token", unique: true
    t.index ["projekt_event_id"], name: "index_projekt_event_registrations_on_projekt_event_id"
    t.index ["user_id"], name: "index_projekt_event_registrations_on_user_id"
  end

  create_table "projekt_events", force: :cascade do |t|
    t.string "title"
    t.string "location"
    t.datetime "datetime"
    t.string "weblink"
    t.integer "projekt_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "description"
    t.datetime "end_datetime"
    t.string "summary"
    t.bigint "projekt_phase_id"
    t.boolean "open_ended", default: false
    t.string "language"
    t.boolean "wheelchair_accessible", default: false
    t.boolean "accessible_toilet", default: false
    t.boolean "disabled_parking_nearby", default: false
    t.boolean "tactile_guidance_systems", default: false
    t.boolean "induction_loop_available", default: false
    t.boolean "assistance_dogs_welcome", default: false
    t.boolean "sign_language_interpreter", default: false
    t.integer "max_attendees"
    t.text "confirmation_email_text"
    t.text "waitlist_email_text"
    t.text "admin_emails"
    t.index ["projekt_phase_id"], name: "index_projekt_events_on_projekt_phase_id"
  end

  create_table "projekt_imports", force: :cascade do |t|
    t.string "status", default: "pending", null: false
    t.text "extracted_text"
    t.jsonb "ai_result"
    t.text "additional_user_instructions"
    t.bigint "user_id", null: false
    t.bigint "projekt_id"
    t.text "error_message"
    t.jsonb "warnings", default: [], null: false
    t.string "image_status", default: "pending", null: false
    t.text "image_error"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "created_projekt_ids", default: [], null: false, array: true
    t.string "failure_stage"
    t.jsonb "error_details", default: {}, null: false
    t.string "content_locale"
    t.jsonb "source_images", default: [], null: false
    t.string "title_image_mode", default: "document", null: false
    t.integer "title_image_index"
    t.index ["created_at"], name: "index_projekt_imports_on_created_at"
    t.index ["projekt_id"], name: "index_projekt_imports_on_projekt_id"
    t.index ["status"], name: "index_projekt_imports_on_status"
    t.index ["user_id"], name: "index_projekt_imports_on_user_id"
  end

  create_table "projekt_label_translations", force: :cascade do |t|
    t.bigint "projekt_label_id", null: false
    t.string "locale", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name"
    t.index ["locale"], name: "index_projekt_label_translations_on_locale"
    t.index ["projekt_label_id"], name: "index_projekt_label_translations_on_projekt_label_id"
  end

  create_table "projekt_labelings", force: :cascade do |t|
    t.bigint "projekt_label_id"
    t.string "labelable_type"
    t.bigint "labelable_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["labelable_type", "labelable_id"], name: "index_projekt_labelings_on_labelable_type_and_labelable_id"
    t.index ["projekt_label_id"], name: "index_projekt_labelings_on_projekt_label_id"
  end

  create_table "projekt_labels", force: :cascade do |t|
    t.string "color"
    t.string "icon"
    t.bigint "projekt_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "projekt_phase_id"
    t.integer "masterportal_collection_id"
    t.index ["projekt_id"], name: "index_projekt_labels_on_projekt_id"
    t.index ["projekt_phase_id", "masterportal_collection_id"], name: "index_projekt_labels_on_phase_and_masterportal_collection", unique: true, where: "(masterportal_collection_id IS NOT NULL)"
    t.index ["projekt_phase_id"], name: "index_projekt_labels_on_projekt_phase_id"
  end

  create_table "projekt_livestreams", force: :cascade do |t|
    t.string "url"
    t.string "video_platform"
    t.string "title"
    t.datetime "starts_at"
    t.text "description"
    t.bigint "projekt_id"
    t.string "external_id"
    t.string "preview_image_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "projekt_phase_id"
    t.index ["projekt_id"], name: "index_projekt_livestreams_on_projekt_id"
    t.index ["projekt_phase_id"], name: "index_projekt_livestreams_on_projekt_phase_id"
  end

  create_table "projekt_manager_assignments", force: :cascade do |t|
    t.bigint "projekt_id"
    t.bigint "projekt_manager_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "permissions", default: [], array: true
    t.index ["projekt_id"], name: "index_projekt_manager_assignments_on_projekt_id"
    t.index ["projekt_manager_id"], name: "index_projekt_manager_assignments_on_projekt_manager_id"
  end

  create_table "projekt_managers", force: :cascade do |t|
    t.bigint "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "manage_all_projekts", default: false, null: false
    t.index ["user_id"], name: "index_projekt_managers_on_user_id"
  end

  create_table "projekt_notifications", force: :cascade do |t|
    t.bigint "projekt_id"
    t.string "title"
    t.text "body"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "projekt_phase_id"
    t.index ["projekt_id"], name: "index_projekt_notifications_on_projekt_id"
    t.index ["projekt_phase_id"], name: "index_projekt_notifications_on_projekt_phase_id"
  end

  create_table "projekt_phase_evaluation_visibilities", force: :cascade do |t|
    t.bigint "projekt_phase_id", null: false
    t.boolean "show_kpis", default: false, null: false
    t.boolean "show_key_metrics", default: false, null: false
    t.boolean "show_phase_summary", default: false, null: false
    t.boolean "show_tone", default: false, null: false
    t.boolean "show_ranking", default: false, null: false
    t.boolean "show_proposals", default: false, null: false
    t.boolean "show_ai_summary", default: false, null: false
    t.boolean "show_timeline", default: false, null: false
    t.boolean "show_label_sentiment", default: false, null: false
    t.boolean "show_user_segments", default: false, null: false
    t.boolean "show_key_findings", default: false, null: false
    t.boolean "show_topic_clustering", default: false, null: false
    t.boolean "show_semantic_clustering", default: false, null: false
    t.boolean "show_ai_questions", default: false, null: false
    t.boolean "show_questions", default: false, null: false
    t.boolean "show_open_responses", default: false, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.boolean "show_budget_segments", default: true, null: false
    t.boolean "show_heatmap", default: false, null: false
    t.boolean "show_poll_stats", default: false, null: false
    t.index ["projekt_phase_id"], name: "index_projekt_phase_evaluation_visibilities_on_projekt_phase_id", unique: true
  end

  create_table "projekt_phase_evaluations", force: :cascade do |t|
    t.bigint "projekt_evaluation_id", null: false
    t.bigint "projekt_phase_id", null: false
    t.jsonb "data", default: {}
    t.string "status", default: "pending", null: false
    t.datetime "generated_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["projekt_evaluation_id", "projekt_phase_id"], name: "index_projekt_phase_evaluations_on_eval_and_phase", unique: true
    t.index ["projekt_evaluation_id"], name: "index_projekt_phase_evaluations_on_projekt_evaluation_id"
    t.index ["projekt_phase_id"], name: "index_projekt_phase_evaluations_on_projekt_phase_id"
    t.index ["status"], name: "index_projekt_phase_evaluations_on_status"
  end

  create_table "projekt_phase_geozones", force: :cascade do |t|
    t.bigint "projekt_phase_id"
    t.bigint "geozone_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["geozone_id"], name: "index_projekt_phase_geozones_on_geozone_id"
    t.index ["projekt_phase_id"], name: "index_projekt_phase_geozones_on_projekt_phase_id"
  end

  create_table "projekt_phase_settings", force: :cascade do |t|
    t.bigint "projekt_phase_id"
    t.string "key"
    t.string "value"
    t.index ["key", "projekt_phase_id"], name: "index_projekt_phase_settings_on_key_and_projekt_phase_id", unique: true
    t.index ["projekt_phase_id"], name: "index_projekt_phase_settings_on_projekt_phase_id"
  end

  create_table "projekt_phase_stat_questions", force: :cascade do |t|
    t.bigint "projekt_phase_id", null: false
    t.text "question", null: false
    t.text "answer"
    t.string "status", default: "pending", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["projekt_phase_id", "created_at"], name: "idx_stat_questions_phase_created"
    t.index ["projekt_phase_id"], name: "index_projekt_phase_stat_questions_on_projekt_phase_id"
  end

  create_table "projekt_phase_subscriptions", force: :cascade do |t|
    t.bigint "projekt_phase_id"
    t.bigint "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["projekt_phase_id"], name: "index_projekt_phase_subscriptions_on_projekt_phase_id"
    t.index ["user_id"], name: "index_projekt_phase_subscriptions_on_user_id"
  end

  create_table "projekt_phase_translations", force: :cascade do |t|
    t.bigint "projekt_phase_id", null: false
    t.string "locale", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "phase_tab_name"
    t.text "cta_button_name"
    t.text "resource_form_title"
    t.text "resource_form_intro"
    t.string "labels_name"
    t.string "sentiments_name"
    t.string "resource_form_title_placeholder"
    t.text "description"
    t.string "comment_form_title"
    t.string "comment_form_button"
    t.text "resource_form_description_placeholder"
    t.text "welcome_text_in_show"
    t.string "support_button_text"
    t.index ["locale"], name: "index_projekt_phase_translations_on_locale"
    t.index ["projekt_phase_id"], name: "index_projekt_phase_translations_on_projekt_phase_id"
  end

  create_table "projekt_phases", force: :cascade do |t|
    t.string "type"
    t.date "start_date"
    t.date "end_date"
    t.string "geozone_restricted"
    t.bigint "projekt_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "active"
    t.bigint "age_range_id"
    t.string "registered_address_grouping_restriction", default: ""
    t.jsonb "registered_address_grouping_restrictions", default: {}, null: false
    t.integer "given_order"
    t.integer "comments_count", default: 0
    t.datetime "hidden_at"
    t.integer "user_status", default: 1
    t.date "lock_on"
    t.boolean "frontend_visibility", default: true, null: false
    t.jsonb "ai_stats", default: {}, null: false
    t.string "ai_stats_refresh_status"
    t.datetime "ai_stats_refreshed_at"
    t.datetime "stats_refreshed_at"
    t.jsonb "stats", default: {}, null: false
    t.string "masterportal_import_status"
    t.datetime "masterportal_last_imported_at"
    t.integer "masterportal_last_imported_count"
    t.text "masterportal_import_error"
    t.string "masterportal_last_endpoint_url"
    t.string "masterportal_last_collection_ids"
    t.string "masterportal_destroy_status"
    t.text "masterportal_destroy_error"
    t.string "mitmachbox_survey_id"
    t.index ["age_range_id"], name: "index_projekt_phases_on_age_range_id"
    t.index ["projekt_id"], name: "index_projekt_phases_on_projekt_id"
    t.index ["registered_address_grouping_restrictions"], name: "index_p_phases_on_ra_grouping_restrictions", using: :gin
  end

  create_table "projekt_point_of_interest_categories", force: :cascade do |t|
    t.bigint "projekt_phase_id", null: false
    t.string "name", null: false
    t.string "color", null: false
    t.string "icon", null: false
    t.integer "position", default: 0
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "masterportal_collection_id"
    t.index ["projekt_phase_id", "masterportal_collection_id"], name: "index_poi_categories_on_phase_and_masterportal_collection", unique: true, where: "(masterportal_collection_id IS NOT NULL)"
    t.index ["projekt_phase_id"], name: "index_projekt_point_of_interest_categories_on_projekt_phase_id"
  end

  create_table "projekt_point_of_interest_pin_translations", force: :cascade do |t|
    t.bigint "projekt_point_of_interest_pin_id", null: false
    t.string "locale", null: false
    t.text "description"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["locale"], name: "index_projekt_point_of_interest_pin_translations_on_locale"
    t.index ["projekt_point_of_interest_pin_id"], name: "index_poi_pin_translations_on_poi_pin_id"
  end

  create_table "projekt_point_of_interest_pins", force: :cascade do |t|
    t.bigint "projekt_phase_id", null: false
    t.integer "projekt_point_of_interest_category_id"
    t.bigint "author_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "source"
    t.string "source_collection"
    t.string "external_id"
    t.string "external_source_url"
    t.bigint "masterportal_pin_id"
    t.index ["author_id"], name: "index_projekt_point_of_interest_pins_on_author_id"
    t.index ["external_id"], name: "index_poi_pins_on_external_id"
    t.index ["masterportal_pin_id"], name: "index_projekt_point_of_interest_pins_on_masterportal_pin_id"
    t.index ["projekt_phase_id", "source", "source_collection"], name: "index_poi_pins_on_phase_source_collection"
    t.index ["projekt_phase_id"], name: "index_projekt_point_of_interest_pins_on_projekt_phase_id"
    t.index ["projekt_point_of_interest_category_id"], name: "projekt_point_of_interest_category"
    t.index ["source", "external_id", "projekt_phase_id"], name: "index_poi_pins_on_source_external_id_projekt_phase_id", unique: true
  end

  create_table "projekt_question_answers", force: :cascade do |t|
    t.bigint "projekt_question_id"
    t.bigint "projekt_question_option_id"
    t.bigint "user_id"
    t.datetime "hidden_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["hidden_at"], name: "index_projekt_question_answers_on_hidden_at"
    t.index ["projekt_question_id"], name: "index_projekt_question_answers_on_projekt_question_id"
    t.index ["projekt_question_option_id"], name: "index_projekt_question_answers_on_projekt_question_option_id"
    t.index ["user_id"], name: "index_projekt_question_answers_on_user_id"
  end

  create_table "projekt_question_option_translations", force: :cascade do |t|
    t.bigint "projekt_question_option_id"
    t.string "locale", null: false
    t.string "value"
    t.datetime "hidden_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["projekt_question_option_id"], name: "option_projekt_question_option_id"
  end

  create_table "projekt_question_options", force: :cascade do |t|
    t.bigint "projekt_question_id"
    t.integer "answers_count", default: 0
    t.datetime "hidden_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["hidden_at"], name: "index_projekt_question_options_on_hidden_at"
    t.index ["projekt_question_id"], name: "index_projekt_question_options_on_projekt_question_id"
  end

  create_table "projekt_question_translations", force: :cascade do |t|
    t.bigint "projekt_question_id"
    t.string "locale", null: false
    t.text "title"
    t.datetime "hidden_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["locale"], name: "index_projekt_question_translations_on_locale"
    t.index ["projekt_question_id"], name: "index_projekt_question_translations_on_projekt_question_id"
  end

  create_table "projekt_questions", force: :cascade do |t|
    t.text "title"
    t.integer "answers_count", default: 0
    t.integer "comments_count", default: 0
    t.integer "author_id", default: 0
    t.datetime "hidden_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "projekt_id"
    t.boolean "comments_enabled", default: true
    t.boolean "show_answers_count", default: true
    t.integer "projekt_livestream_id"
    t.bigint "projekt_phase_id"
    t.index ["hidden_at"], name: "index_projekt_questions_on_hidden_at"
    t.index ["projekt_id"], name: "index_projekt_questions_on_projekt_id"
    t.index ["projekt_livestream_id"], name: "index_projekt_questions_on_projekt_livestream_id"
    t.index ["projekt_phase_id"], name: "index_projekt_questions_on_projekt_phase_id"
  end

  create_table "projekt_settings", force: :cascade do |t|
    t.bigint "projekt_id"
    t.string "key"
    t.string "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key", "value", "projekt_id"], name: "index_projekt_settings_on_key_and_value_and_projekt_id"
    t.index ["projekt_id", "key", "value"], name: "index_projekt_settings_on_projekt_id_key_value"
    t.index ["projekt_id"], name: "index_projekt_settings_on_projekt_id"
  end

  create_table "projekt_subscriptions", force: :cascade do |t|
    t.bigint "projekt_id"
    t.bigint "user_id"
    t.boolean "active", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["projekt_id"], name: "index_projekt_subscriptions_on_projekt_id"
    t.index ["user_id"], name: "index_projekt_subscriptions_on_user_id"
  end

  create_table "projekt_translations", force: :cascade do |t|
    t.bigint "projekt_id", null: false
    t.string "locale", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "description"
    t.index ["locale"], name: "index_projekt_translations_on_locale"
    t.index ["projekt_id"], name: "index_projekt_translations_on_projekt_id"
  end

  create_table "projekts", force: :cascade do |t|
    t.string "name"
    t.bigint "parent_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "order_number"
    t.date "total_duration_start"
    t.date "total_duration_end"
    t.integer "comments_count", default: 0
    t.datetime "hidden_at"
    t.integer "author_id"
    t.string "geozone_affiliated"
    t.string "color"
    t.string "icon"
    t.integer "level", default: 1
    t.boolean "special", default: false
    t.string "special_name"
    t.boolean "show_start_date_in_frontend", default: true
    t.boolean "show_end_date_in_frontend", default: true
    t.integer "top_level_projekt_id"
    t.tsvector "tsv"
    t.boolean "new_content_block_mode"
    t.string "preview_code"
    t.boolean "on_dt_global_overview", default: false
    t.boolean "from_dt", default: false
    t.string "import_file_status"
    t.jsonb "import_file_data"
    t.boolean "show_content_background", default: true
    t.bigint "landing_page_id"
    t.datetime "published_at"
    t.boolean "imported_by_ai", default: false, null: false
    t.string "banner_image_generation_status"
    t.datetime "content_updated_at"
    t.boolean "activated", default: false, null: false
    t.boolean "show_in_navigation", default: true, null: false
    t.boolean "show_in_overview_page", default: true, null: false
    t.boolean "show_in_overview_page_navigation", default: false, null: false
    t.boolean "show_in_homepage", default: true, null: false
    t.boolean "show_in_individual_list", default: false, null: false
    t.boolean "show_in_sidebar_filter", default: true, null: false
    t.datetime "whatsapp_broadcast_sent_at"
    t.string "whatsapp_broadcast_slug"
    t.string "copy_status"
    t.bigint "copied_from_projekt_id"
    t.index ["activated"], name: "index_projekts_on_activated"
    t.index ["copied_from_projekt_id"], name: "index_projekts_on_copied_from_projekt_id"
    t.index ["imported_by_ai"], name: "index_projekts_on_imported_by_ai"
    t.index ["landing_page_id"], name: "index_projekts_on_landing_page_id"
    t.index ["on_dt_global_overview"], name: "index_projekts_on_on_dt_global_overview"
    t.index ["parent_id"], name: "index_projekts_on_parent_id"
    t.index ["published_at"], name: "index_projekts_on_published_at"
    t.index ["show_in_homepage"], name: "index_projekts_on_show_in_homepage"
    t.index ["show_in_individual_list"], name: "index_projekts_on_show_in_individual_list"
    t.index ["show_in_navigation"], name: "index_projekts_on_show_in_navigation"
    t.index ["show_in_overview_page"], name: "index_projekts_on_show_in_overview_page"
    t.index ["show_in_overview_page_navigation"], name: "index_projekts_on_show_in_overview_page_navigation"
    t.index ["show_in_sidebar_filter"], name: "index_projekts_on_show_in_sidebar_filter"
    t.index ["tsv"], name: "index_projekts_on_tsv", using: :gin
  end

  create_table "projekts_registered_address_districts", id: false, force: :cascade do |t|
    t.bigint "projekt_id", null: false
    t.bigint "registered_address_district_id", null: false
    t.index ["projekt_id", "registered_address_district_id"], name: "idx_projekts_ra_districts_on_projekt_and_district", unique: true
  end

  create_table "proposal_notifications", id: :serial, force: :cascade do |t|
    t.string "title"
    t.text "body"
    t.integer "author_id"
    t.integer "proposal_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "moderated", default: false
    t.datetime "hidden_at"
    t.datetime "ignored_at"
    t.datetime "confirmed_hide_at"
  end

  create_table "proposal_translations", id: :serial, force: :cascade do |t|
    t.integer "proposal_id", null: false
    t.string "locale", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "title"
    t.text "description"
    t.text "summary"
    t.text "retired_explanation"
    t.datetime "hidden_at"
    t.index ["hidden_at"], name: "index_proposal_translations_on_hidden_at"
    t.index ["locale"], name: "index_proposal_translations_on_locale"
    t.index ["proposal_id"], name: "index_proposal_translations_on_proposal_id"
  end

  create_table "proposals", id: :serial, force: :cascade do |t|
    t.integer "author_id"
    t.datetime "hidden_at"
    t.integer "flags_count", default: 0
    t.datetime "ignored_flag_at"
    t.integer "cached_votes_up", default: 0
    t.integer "comments_count", default: 0
    t.datetime "confirmed_hide_at"
    t.bigint "hot_score", default: 0
    t.integer "confidence_score", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "responsible_name", limit: 60
    t.string "video_url"
    t.tsvector "tsv"
    t.integer "geozone_id"
    t.datetime "retired_at"
    t.string "retired_reason"
    t.integer "community_id"
    t.datetime "published_at"
    t.boolean "selected", default: false
    t.bigint "projekt_id"
    t.string "on_behalf_of"
    t.bigint "projekt_phase_id"
    t.bigint "sentiment_id"
    t.text "official_answer", default: ""
    t.integer "cached_votes_down", default: 0
    t.integer "officing_bulk_votes", default: 0
    t.boolean "admin_accepted", default: true, null: false
    t.boolean "draft", default: false, null: false
    t.text "ai_idea_text"
    t.jsonb "ai_evaluation_result"
    t.text "ai_image_prompt"
    t.string "source"
    t.string "source_collection"
    t.string "external_id"
    t.string "external_source_url"
    t.bigint "masterportal_pin_id"
    t.boolean "generated_image", default: false, null: false
    t.index ["author_id", "hidden_at"], name: "index_proposals_on_author_id_and_hidden_at"
    t.index ["author_id"], name: "index_proposals_on_author_id"
    t.index ["cached_votes_down"], name: "index_proposals_on_cached_votes_down"
    t.index ["cached_votes_up"], name: "index_proposals_on_cached_votes_up"
    t.index ["community_id"], name: "index_proposals_on_community_id"
    t.index ["confidence_score"], name: "index_proposals_on_confidence_score"
    t.index ["draft"], name: "index_proposals_on_draft"
    t.index ["external_id"], name: "index_proposals_on_external_id"
    t.index ["geozone_id"], name: "index_proposals_on_geozone_id"
    t.index ["hidden_at"], name: "index_proposals_on_hidden_at"
    t.index ["hot_score"], name: "index_proposals_on_hot_score"
    t.index ["masterportal_pin_id"], name: "index_proposals_on_masterportal_pin_id"
    t.index ["projekt_id"], name: "index_proposals_on_projekt_id"
    t.index ["projekt_phase_id", "source", "source_collection"], name: "index_proposals_on_phase_source_collection"
    t.index ["projekt_phase_id"], name: "index_proposals_on_projekt_phase_id"
    t.index ["selected"], name: "index_proposals_on_selected"
    t.index ["sentiment_id"], name: "index_proposals_on_sentiment_id"
    t.index ["source", "external_id", "projekt_phase_id"], name: "index_proposals_on_source_external_id_projekt_phase_id", unique: true
    t.index ["tsv"], name: "index_proposals_on_tsv", using: :gin
  end

  create_table "recipient_group_filters", force: :cascade do |t|
    t.bigint "recipient_group_id", null: false
    t.integer "position", default: 0, null: false
    t.string "kind", null: false
    t.string "operator", default: "include", null: false
    t.jsonb "params", default: {}, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["kind"], name: "index_recipient_group_filters_on_kind"
    t.index ["recipient_group_id", "position"], name: "index_rgf_on_recipient_group_id_and_position"
    t.index ["recipient_group_id"], name: "index_recipient_group_filters_on_recipient_group_id"
  end

  create_table "recipient_groups", force: :cascade do |t|
    t.string "name"
    t.string "origin_class_name"
    t.string "origin_class_object_id"
    t.string "access_method"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "registered_address_cities", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "registered_address_district_projekt_phases", force: :cascade do |t|
    t.bigint "registered_address_district_id"
    t.bigint "projekt_phase_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["projekt_phase_id"], name: "index_rad_projekt_phases_on_projekt_phase_id"
    t.index ["registered_address_district_id"], name: "index_rad_projekt_phases_on_rad_id"
  end

  create_table "registered_address_districts", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "default_deficiency_report_responsible_type"
    t.bigint "default_deficiency_report_responsible_id"
    t.bigint "idea_officer_id"
    t.index ["default_deficiency_report_responsible_type", "default_deficiency_report_responsible_id"], name: "index_registered_address_districts_on_default_dr_responsible"
    t.index ["idea_officer_id"], name: "index_registered_address_districts_on_idea_officer_id"
  end

  create_table "registered_address_groupings", force: :cascade do |t|
    t.string "key"
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "registered_address_street_projekt_phases", force: :cascade do |t|
    t.bigint "registered_address_street_id"
    t.bigint "projekt_phase_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["projekt_phase_id"], name: "index_ras_projekt_phases_on_projekt_phase_id"
    t.index ["registered_address_street_id"], name: "index_ras_projekt_phases_on_ras_id"
  end

  create_table "registered_address_streets", force: :cascade do |t|
    t.string "name"
    t.string "plz"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name", "plz"], name: "index_registered_address_streets_on_name_and_plz", unique: true
  end

  create_table "registered_addresses", force: :cascade do |t|
    t.string "street_number"
    t.string "street_number_extension"
    t.jsonb "groupings", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "registered_address_street_id"
    t.integer "registered_address_city_id"
    t.bigint "registered_address_district_id"
    t.index ["groupings"], name: "index_registered_addresses_on_groupings", using: :gin
    t.index ["registered_address_district_id"], name: "index_registered_addresses_on_registered_address_district_id"
    t.index ["registered_address_street_id"], name: "index_registered_addresses_on_registered_address_street_id"
  end

  create_table "related_content_scores", id: :serial, force: :cascade do |t|
    t.integer "user_id"
    t.integer "related_content_id"
    t.integer "value"
    t.index ["related_content_id"], name: "index_related_content_scores_on_related_content_id"
    t.index ["user_id", "related_content_id"], name: "unique_user_related_content_scoring", unique: true
    t.index ["user_id"], name: "index_related_content_scores_on_user_id"
  end

  create_table "related_contents", id: :serial, force: :cascade do |t|
    t.string "parent_relationable_type"
    t.integer "parent_relationable_id"
    t.string "child_relationable_type"
    t.integer "child_relationable_id"
    t.integer "related_content_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "hidden_at"
    t.integer "related_content_scores_count", default: 0
    t.integer "author_id"
    t.boolean "machine_learning", default: false
    t.integer "machine_learning_score", default: 0
    t.index ["child_relationable_type", "child_relationable_id"], name: "index_related_contents_on_child_relationable"
    t.index ["hidden_at"], name: "index_related_contents_on_hidden_at"
    t.index ["parent_relationable_id", "parent_relationable_type", "child_relationable_id", "child_relationable_type"], name: "unique_parent_child_related_content", unique: true
    t.index ["parent_relationable_type", "parent_relationable_id"], name: "index_related_contents_on_parent_relationable"
    t.index ["related_content_id"], name: "opposite_related_content"
  end

  create_table "relay_states", force: :cascade do |t|
    t.string "token"
    t.jsonb "data", default: {}
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["token"], name: "index_relay_states_on_token"
  end

  create_table "remote_translations", id: :serial, force: :cascade do |t|
    t.string "locale"
    t.integer "remote_translatable_id"
    t.string "remote_translatable_type"
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "reports", id: :serial, force: :cascade do |t|
    t.boolean "stats"
    t.boolean "results"
    t.string "process_type"
    t.integer "process_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "advanced_stats"
    t.index ["process_type", "process_id"], name: "index_reports_on_process_type_and_process_id"
  end

  create_table "resource_sentiments", force: :cascade do |t|
    t.bigint "sentiment_id"
    t.string "sentimentable_type"
    t.bigint "sentimentable_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["sentiment_id"], name: "index_resource_sentiments_on_sentiment"
    t.index ["sentimentable_type", "sentimentable_id"], name: "index_resource_sentiments_on_sentimentable"
  end

  create_table "saved_content_blocks", force: :cascade do |t|
    t.text "content"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.bigint "user_id"
    t.string "context", default: "projekt", null: false
    t.index ["context"], name: "index_saved_content_blocks_on_context"
    t.index ["user_id"], name: "index_saved_content_blocks_on_user_id"
  end

  create_table "sdg_goals", force: :cascade do |t|
    t.integer "code", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_sdg_goals_on_code", unique: true
  end

  create_table "sdg_local_target_translations", force: :cascade do |t|
    t.bigint "sdg_local_target_id", null: false
    t.string "locale", null: false
    t.string "title"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["locale"], name: "index_sdg_local_target_translations_on_locale"
    t.index ["sdg_local_target_id"], name: "index_sdg_local_target_translations_on_sdg_local_target_id"
  end

  create_table "sdg_local_targets", force: :cascade do |t|
    t.bigint "target_id"
    t.string "code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "goal_id"
    t.index ["code"], name: "index_sdg_local_targets_on_code", unique: true
    t.index ["goal_id"], name: "index_sdg_local_targets_on_goal_id"
    t.index ["target_id"], name: "index_sdg_local_targets_on_target_id"
  end

  create_table "sdg_managers", force: :cascade do |t|
    t.bigint "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sdg_managers_on_user_id", unique: true
  end

  create_table "sdg_phases", force: :cascade do |t|
    t.integer "kind", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["kind"], name: "index_sdg_phases_on_kind", unique: true
  end

  create_table "sdg_relations", force: :cascade do |t|
    t.string "related_sdg_type"
    t.bigint "related_sdg_id"
    t.string "relatable_type"
    t.bigint "relatable_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["relatable_type", "relatable_id"], name: "index_sdg_relations_on_relatable_type_and_relatable_id"
    t.index ["related_sdg_id", "related_sdg_type", "relatable_id", "relatable_type"], name: "sdg_relations_unique", unique: true
    t.index ["related_sdg_type", "related_sdg_id"], name: "index_sdg_relations_on_related_sdg_type_and_related_sdg_id"
  end

  create_table "sdg_reviews", force: :cascade do |t|
    t.string "relatable_type"
    t.bigint "relatable_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["relatable_type", "relatable_id"], name: "index_sdg_reviews_on_relatable_type_and_relatable_id", unique: true
  end

  create_table "sdg_targets", force: :cascade do |t|
    t.bigint "goal_id"
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_sdg_targets_on_code", unique: true
    t.index ["goal_id"], name: "index_sdg_targets_on_goal_id"
  end

  create_table "section_activities", force: :cascade do |t|
    t.bigint "user_id"
    t.string "section", null: false
    t.string "trackable_type"
    t.bigint "trackable_id"
    t.string "action", null: false
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.index ["section", "created_at"], name: "index_section_activities_on_section_and_created_at"
    t.index ["trackable_type", "trackable_id"], name: "index_section_activities_on_trackable_type_and_trackable_id"
    t.index ["user_id"], name: "index_section_activities_on_user_id"
  end

  create_table "section_contact_people", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "section", null: false
    t.string "role"
    t.string "email"
    t.string "phone"
    t.integer "position", default: 0
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["section", "position"], name: "index_section_contact_people_on_section_and_position"
    t.index ["user_id"], name: "index_section_contact_people_on_user_id"
  end

  create_table "sentiment_translations", force: :cascade do |t|
    t.bigint "sentiment_id", null: false
    t.string "locale", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name"
    t.index ["locale"], name: "index_sentiment_translations_on_locale"
    t.index ["sentiment_id"], name: "index_sentiment_translations_on_sentiment_id"
  end

  create_table "sentiments", force: :cascade do |t|
    t.string "color"
    t.bigint "projekt_phase_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["projekt_phase_id"], name: "index_sentiments_on_projekt_phase_id"
  end

  create_table "settings", id: :serial, force: :cascade do |t|
    t.string "key"
    t.string "value"
    t.index ["key"], name: "index_settings_on_key"
  end

  create_table "signature_sheets", id: :serial, force: :cascade do |t|
    t.string "signable_type"
    t.integer "signable_id"
    t.text "required_fields_to_verify"
    t.boolean "processed", default: false
    t.integer "author_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "title"
  end

  create_table "signatures", id: :serial, force: :cascade do |t|
    t.integer "signature_sheet_id"
    t.integer "user_id"
    t.string "document_number"
    t.boolean "verified", default: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.date "date_of_birth"
    t.string "postal_code"
  end

  create_table "site_customization_content_blocks", id: :serial, force: :cascade do |t|
    t.string "name"
    t.string "locale"
    t.text "body"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "key"
    t.integer "projekt_id"
    t.integer "position"
    t.integer "margin_bottom"
    t.jsonb "ai_generation_data"
    t.integer "newsletter_id"
    t.index "((ai_generation_data ->> 'status'::text))", name: "index_site_customization_content_blocks_on_ai_status"
    t.index ["key", "name", "locale"], name: "locale_key_name_index", unique: true
    t.index ["newsletter_id"], name: "index_site_customization_content_blocks_on_newsletter_id"
  end

  create_table "site_customization_content_card_translations", force: :cascade do |t|
    t.bigint "site_customization_content_card_id", null: false
    t.string "locale", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "title"
    t.index ["locale"], name: "index_site_customization_content_card_translations_on_locale"
    t.index ["site_customization_content_card_id"], name: "index_6a35fd735afb61c8b9736c45c2156ce1e4ec47e6"
  end

  create_table "site_customization_content_cards", force: :cascade do |t|
    t.integer "given_order"
    t.boolean "active", default: false
    t.jsonb "settings", default: {}
    t.string "kind"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "landing_page_id"
    t.index ["landing_page_id"], name: "index_site_customization_content_cards_on_landing_page_id"
  end

  create_table "site_customization_email_templates", force: :cascade do |t|
    t.bigint "projekt_phase_id"
    t.string "mailer_class", null: false
    t.string "mailer_action", null: false
    t.string "locale", default: "de", null: false
    t.string "subject"
    t.text "body"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["projekt_phase_id", "mailer_class", "mailer_action", "locale"], name: "idx_email_templates_on_phase_mailer_action_locale", unique: true
    t.index ["projekt_phase_id"], name: "index_site_customization_email_templates_on_projekt_phase_id"
  end

  create_table "site_customization_images", id: :serial, force: :cascade do |t|
    t.string "name", null: false
    t.string "image_file_name"
    t.string "image_content_type"
    t.bigint "image_file_size"
    t.datetime "image_updated_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_site_customization_images_on_name", unique: true
  end

  create_table "site_customization_page_translations", id: :serial, force: :cascade do |t|
    t.integer "site_customization_page_id", null: false
    t.string "locale", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "title"
    t.string "subtitle"
    t.text "content"
    t.text "content_bu"
    t.string "header_title"
    t.index ["locale"], name: "index_site_customization_page_translations_on_locale"
    t.index ["site_customization_page_id"], name: "index_7fa0f9505738cb31a31f11fb2f4c4531fed7178b"
  end

  create_table "site_customization_pages", id: :serial, force: :cascade do |t|
    t.string "slug", null: false
    t.boolean "more_info_flag"
    t.boolean "print_content_flag"
    t.string "status", default: "draft"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "locale"
    t.bigint "projekt_id"
    t.boolean "landing_show_in_top_nav", default: false
    t.boolean "landing_hide_title_and_subtitle", default: false
    t.boolean "landing", default: false
    t.integer "landing_nav_position"
    t.boolean "landing_site_logo_follow_to_landing_page", default: false
    t.string "landing_navigation_link_color", default: "#000000"
    t.string "brand_color"
    t.datetime "published_at"
    t.string "footer_key"
    t.integer "footer_position"
    t.index ["footer_key"], name: "index_site_customization_pages_on_footer_key", unique: true
    t.index ["landing_show_in_top_nav"], name: "pages_landing_show_in_top_nav"
    t.index ["projekt_id"], name: "index_site_customization_pages_on_projekt_id"
  end

  create_table "site_customization_videos", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["name"], name: "index_site_customization_videos_on_name", unique: true
  end

  create_table "stats_versions", id: :serial, force: :cascade do |t|
    t.string "process_type"
    t.integer "process_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["process_type", "process_id"], name: "index_stats_versions_on_process_type_and_process_id"
  end

  create_table "taggings", id: :serial, force: :cascade do |t|
    t.integer "tag_id"
    t.string "taggable_type"
    t.integer "taggable_id"
    t.string "tagger_type"
    t.integer "tagger_id"
    t.string "context", limit: 128
    t.datetime "created_at"
    t.index ["context"], name: "index_taggings_on_context"
    t.index ["tag_id", "taggable_id", "taggable_type", "context", "tagger_id", "tagger_type"], name: "taggings_idx", unique: true
    t.index ["tag_id"], name: "index_taggings_on_tag_id"
    t.index ["taggable_id", "taggable_type", "context"], name: "index_taggings_on_taggable_id_and_taggable_type_and_context"
    t.index ["taggable_id", "taggable_type", "tagger_id", "context"], name: "taggings_idy"
    t.index ["taggable_id"], name: "index_taggings_on_taggable_id"
    t.index ["taggable_type"], name: "index_taggings_on_taggable_type"
    t.index ["tagger_id", "tagger_type"], name: "index_taggings_on_tagger_id_and_tagger_type"
    t.index ["tagger_id"], name: "index_taggings_on_tagger_id"
  end

  create_table "tags", id: :serial, force: :cascade do |t|
    t.string "name", limit: 160
    t.integer "taggings_count", default: 0
    t.integer "debates_count", default: 0
    t.integer "proposals_count", default: 0
    t.string "kind"
    t.integer "budget_investments_count", default: 0
    t.integer "legislation_proposals_count", default: 0
    t.integer "legislation_processes_count", default: 0
    t.integer "polls_count", default: 0
    t.integer "custom_logic_category_code", default: 0
    t.integer "custom_logic_subcategory_code", default: 0
    t.boolean "custom_logic_category_cloud"
    t.boolean "custom_logic_subcategory_cloud"
    t.boolean "custom_logic_usertags_cloud"
    t.integer "projekts_count", default: 0
    t.index ["debates_count"], name: "index_tags_on_debates_count"
    t.index ["legislation_processes_count"], name: "index_tags_on_legislation_processes_count"
    t.index ["legislation_proposals_count"], name: "index_tags_on_legislation_proposals_count"
    t.index ["name"], name: "index_tags_on_name", unique: true
    t.index ["proposals_count"], name: "index_tags_on_proposals_count"
  end

  create_table "topics", id: :serial, force: :cascade do |t|
    t.string "title", null: false
    t.text "description"
    t.integer "author_id"
    t.integer "comments_count", default: 0
    t.integer "community_id"
    t.datetime "hidden_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["community_id"], name: "index_topics_on_community_id"
    t.index ["hidden_at"], name: "index_topics_on_hidden_at"
  end

  create_table "unregistered_newsletter_subscribers", force: :cascade do |t|
    t.string "email"
    t.boolean "confirmed", default: false
    t.string "confirmation_token"
    t.string "unsubscribe_token"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "user_individual_group_values", force: :cascade do |t|
    t.bigint "user_id"
    t.bigint "individual_group_value_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["individual_group_value_id"], name: "index_user_individual_group_values_on_individual_group_value_id"
    t.index ["user_id", "individual_group_value_id"], name: "index_user_ig_values_on_user_id_and_ig_value_id", unique: true
    t.index ["user_id"], name: "index_user_individual_group_values_on_user_id"
  end

  create_table "user_resource_criteria", force: :cascade do |t|
    t.bigint "projekt_phase_id", null: false
    t.text "text"
    t.integer "position", default: 0, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "kind", default: "hard", null: false
    t.string "name", null: false
    t.text "description"
    t.text "ai_instruction", null: false
    t.index ["projekt_phase_id", "kind", "position"], name: "idx_urc_phase_kind_position"
    t.index ["projekt_phase_id", "position"], name: "idx_pf_proposal_criteria_phase_position"
    t.index ["projekt_phase_id"], name: "index_user_resource_criteria_on_projekt_phase_id"
  end

  create_table "users", id: :serial, force: :cascade do |t|
    t.string "email", default: ""
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.boolean "email_on_comment", default: false
    t.boolean "email_on_comment_reply", default: false
    t.string "phone_number", limit: 30
    t.string "official_position"
    t.integer "official_level", default: 0
    t.datetime "hidden_at"
    t.string "sms_confirmation_code"
    t.string "username", limit: 60
    t.string "document_number"
    t.string "document_type"
    t.datetime "residence_verified_at"
    t.string "email_verification_token"
    t.datetime "verified_at"
    t.string "unconfirmed_phone"
    t.string "confirmed_phone"
    t.datetime "letter_requested_at"
    t.datetime "confirmed_hide_at"
    t.string "letter_verification_code"
    t.integer "failed_census_calls_count", default: 0
    t.datetime "level_two_verified_at"
    t.string "erase_reason"
    t.datetime "erased_at"
    t.boolean "public_activity", default: true
    t.boolean "newsletter", default: false
    t.integer "notifications_count", default: 0
    t.boolean "registering_with_oauth", default: false
    t.string "locale"
    t.string "oauth_email"
    t.integer "geozone_id"
    t.string "redeemable_code"
    t.string "gender", limit: 10
    t.datetime "date_of_birth"
    t.boolean "email_on_proposal_notification", default: true
    t.boolean "email_digest", default: true
    t.boolean "email_on_direct_message", default: true
    t.boolean "official_position_badge", default: false
    t.datetime "password_changed_at", default: "2015-01-01 01:01:01", null: false
    t.boolean "created_from_signature", default: false
    t.integer "failed_email_digests_count", default: 0
    t.text "former_users_data_log", default: ""
    t.integer "balloted_heading_id"
    t.boolean "public_interests", default: false
    t.boolean "recommended_debates", default: true
    t.boolean "recommended_proposals", default: true
    t.string "subscriptions_token"
    t.string "street_number"
    t.string "document_last_digits"
    t.string "first_name"
    t.string "last_name"
    t.string "street_name"
    t.integer "plz"
    t.string "city_name"
    t.string "unique_stamp"
    t.boolean "adm_email_on_new_comment", default: false
    t.boolean "adm_email_on_new_proposal", default: false
    t.boolean "adm_email_on_new_debate", default: false
    t.boolean "adm_email_on_new_deficiency_report", default: false
    t.bigint "city_street_id"
    t.boolean "adm_email_on_new_manual_verification", default: false
    t.bigint "registered_address_id"
    t.string "street_number_extension"
    t.boolean "prefer_wide_resources_list_view_mode"
    t.boolean "guest", default: false
    t.boolean "show_in_users_overview", default: true
    t.boolean "adm_email_on_new_topic", default: false
    t.string "temporary_auth_token"
    t.datetime "temporary_auth_token_valid_until"
    t.string "auth_image_link"
    t.string "last_stork_level"
    t.boolean "reverify", default: true
    t.boolean "on_dt", default: false
    t.boolean "adm_email_on_new_budget_investment", default: false
    t.integer "api_client_id"
    t.string "keycloak_link"
    t.text "keycloak_id_token", default: ""
    t.string "guest_user_agent"
    t.boolean "system_user", default: false, null: false
    t.string "company_name"
    t.index ["city_street_id"], name: "index_users_on_city_street_id"
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["date_of_birth"], name: "index_users_on_date_of_birth"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["gender"], name: "index_users_on_gender"
    t.index ["geozone_id"], name: "index_users_on_geozone_id"
    t.index ["hidden_at"], name: "index_users_on_hidden_at"
    t.index ["password_changed_at"], name: "index_users_on_password_changed_at"
    t.index ["registered_address_id"], name: "index_users_on_registered_address_id"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["system_user"], name: "index_users_on_single_system_user", unique: true, where: "(\"system_user\" = true)"
    t.index ["username"], name: "index_users_on_username"
  end

  create_table "valuator_groups", id: :serial, force: :cascade do |t|
    t.string "name"
    t.integer "budget_investments_count", default: 0
  end

  create_table "valuators", id: :serial, force: :cascade do |t|
    t.integer "user_id"
    t.string "description"
    t.integer "budget_investments_count", default: 0
    t.integer "valuator_group_id"
    t.boolean "can_comment", default: true
    t.boolean "can_edit_dossier", default: true
    t.index ["user_id"], name: "index_valuators_on_user_id"
  end

  create_table "verified_users", id: :serial, force: :cascade do |t|
    t.string "document_number"
    t.string "document_type"
    t.string "phone"
    t.string "email"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["document_number"], name: "index_verified_users_on_document_number"
    t.index ["email"], name: "index_verified_users_on_email"
    t.index ["phone"], name: "index_verified_users_on_phone"
  end

  create_table "visits", id: :uuid, default: nil, force: :cascade do |t|
    t.uuid "visitor_id"
    t.string "ip"
    t.text "user_agent"
    t.text "referrer"
    t.text "landing_page"
    t.integer "user_id"
    t.string "referring_domain"
    t.string "search_keyword"
    t.string "browser"
    t.string "os"
    t.string "device_type"
    t.integer "screen_height"
    t.integer "screen_width"
    t.string "country"
    t.string "region"
    t.string "city"
    t.string "postal_code"
    t.decimal "latitude"
    t.decimal "longitude"
    t.string "utm_source"
    t.string "utm_medium"
    t.string "utm_term"
    t.string "utm_content"
    t.string "utm_campaign"
    t.datetime "started_at"
    t.index ["started_at"], name: "index_visits_on_started_at"
    t.index ["user_id"], name: "index_visits_on_user_id"
  end

  create_table "votation_type_translations", force: :cascade do |t|
    t.bigint "votation_type_id", null: false
    t.string "locale", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "min_rating_scale_label"
    t.string "max_rating_scale_label"
    t.index ["locale"], name: "index_votation_type_translations_on_locale"
    t.index ["votation_type_id"], name: "index_votation_type_translations_on_votation_type_id"
  end

  create_table "votation_types", force: :cascade do |t|
    t.integer "questionable_id"
    t.string "questionable_type"
    t.integer "vote_type"
    t.integer "max_votes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "max_votes_per_answer"
    t.boolean "show_hint_callout", default: false
  end

  create_table "votes", id: :serial, force: :cascade do |t|
    t.string "votable_type"
    t.integer "votable_id"
    t.string "voter_type"
    t.integer "voter_id"
    t.boolean "vote_flag"
    t.string "vote_scope"
    t.integer "vote_weight"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "signature_id"
    t.boolean "conditional", default: false, null: false
    t.index ["conditional"], name: "index_votes_on_conditional", where: "conditional"
    t.index ["signature_id"], name: "index_votes_on_signature_id"
    t.index ["votable_id", "votable_type", "vote_scope"], name: "index_votes_on_votable_id_and_votable_type_and_vote_scope"
    t.index ["voter_id", "voter_type", "vote_scope"], name: "index_votes_on_voter_id_and_voter_type_and_vote_scope"
  end

  create_table "web_sections", id: :serial, force: :cascade do |t|
    t.text "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "whatsapp_accounts", force: :cascade do |t|
    t.string "wa_id", null: false
    t.string "phone"
    t.string "profile_name"
    t.integer "user_id"
    t.string "state", default: "unlinked", null: false
    t.datetime "verified_at"
    t.datetime "opt_in_at"
    t.datetime "opt_out_at"
    t.datetime "last_inbound_at"
    t.string "link_token"
    t.datetime "link_token_sent_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.boolean "notify_new_projekt", default: true, null: false
    t.boolean "notify_deadline_approaching", default: true, null: false
    t.boolean "notify_deadline_passed", default: true, null: false
    t.boolean "notify_new_supports", default: true, null: false
    t.boolean "notify_new_comments", default: true, null: false
    t.boolean "notify_moderation_decision", default: true, null: false
    t.datetime "ai_disclosed_at"
    t.bigint "guest_user_id"
    t.datetime "terms_accepted_at"
    t.string "reply_language"
    t.datetime "reply_language_settled_at"
    t.index "COALESCE(last_inbound_at, created_at) DESC", name: "index_whatsapp_accounts_on_last_activity"
    t.index ["guest_user_id"], name: "index_whatsapp_accounts_on_guest_user_id", unique: true
    t.index ["last_inbound_at"], name: "index_whatsapp_accounts_on_last_inbound_at"
    t.index ["link_token"], name: "index_whatsapp_accounts_on_link_token", unique: true
    t.index ["user_id"], name: "index_whatsapp_accounts_on_user_id", unique: true
    t.index ["verified_at", "opt_out_at"], name: "index_whatsapp_accounts_on_verified_at_and_opt_out_at"
    t.index ["wa_id"], name: "index_whatsapp_accounts_on_wa_id", unique: true
  end

  create_table "whatsapp_contribution_translations", force: :cascade do |t|
    t.string "contribution_type", null: false
    t.bigint "contribution_id", null: false
    t.string "source_language", null: false
    t.string "locale", null: false
    t.text "title"
    t.text "description"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["contribution_type", "contribution_id", "locale"], name: "index_whatsapp_contribution_translations_on_contribution", unique: true
  end

  create_table "whatsapp_conversations", force: :cascade do |t|
    t.integer "whatsapp_account_id", null: false
    t.string "step", default: "idle", null: false
    t.integer "projekt_phase_id"
    t.jsonb "context", default: {}, null: false
    t.integer "revisions_count", default: 0, null: false
    t.datetime "last_inbound_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "draft_resource_type"
    t.bigint "draft_resource_id"
    t.index ["draft_resource_type", "draft_resource_id"], name: "index_whatsapp_conversations_on_draft_resource"
    t.index ["projekt_phase_id"], name: "index_whatsapp_conversations_on_projekt_phase_id"
    t.index ["whatsapp_account_id"], name: "index_whatsapp_conversations_on_whatsapp_account_id", unique: true
  end

  create_table "whatsapp_messages", force: :cascade do |t|
    t.integer "whatsapp_account_id", null: false
    t.string "direction", null: false
    t.string "kind", default: "text", null: false
    t.text "body"
    t.string "wa_message_id"
    t.string "status"
    t.datetime "sent_at"
    t.jsonb "error", default: {}, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "projekt_id"
    t.string "language"
    t.index ["created_at"], name: "index_whatsapp_messages_on_created_at"
    t.index ["wa_message_id"], name: "index_whatsapp_messages_on_wa_message_id", unique: true
    t.index ["whatsapp_account_id", "projekt_id", "kind"], name: "index_whatsapp_messages_on_account_projekt_kind"
    t.index ["whatsapp_account_id"], name: "index_whatsapp_messages_on_whatsapp_account_id"
  end

  create_table "whatsapp_notification_deliveries", force: :cascade do |t|
    t.bigint "whatsapp_account_id", null: false
    t.bigint "projekt_phase_id"
    t.string "kind", null: false
    t.datetime "sent_at", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["whatsapp_account_id", "projekt_phase_id", "kind"], name: "index_whatsapp_notification_deliveries_on_account_phase_kind", unique: true
  end

  create_table "whatsapp_webhook_events", force: :cascade do |t|
    t.jsonb "payload", default: {}, null: false
    t.datetime "processed_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["created_at"], name: "index_whatsapp_webhook_events_on_created_at"
    t.index ["processed_at"], name: "index_whatsapp_webhook_events_on_processed_at"
  end

  create_table "widget_card_translations", id: :serial, force: :cascade do |t|
    t.integer "widget_card_id", null: false
    t.string "locale", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "label"
    t.string "title"
    t.text "description"
    t.string "link_text"
    t.index ["locale"], name: "index_widget_card_translations_on_locale"
    t.index ["widget_card_id"], name: "index_widget_card_translations_on_widget_card_id"
  end

  create_table "widget_cards", id: :serial, force: :cascade do |t|
    t.string "link_url"
    t.boolean "header", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "cardable_id"
    t.integer "columns", default: 4
    t.string "cardable_type", default: "SiteCustomization::Page"
    t.string "card_category", default: ""
    t.index ["cardable_id"], name: "index_widget_cards_on_cardable_id"
  end

  create_table "widget_feeds", id: :serial, force: :cascade do |t|
    t.string "kind"
    t.integer "limit", default: 3
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "administrators", "users"
  add_foreign_key "age_range_projekt_phases", "age_ranges"
  add_foreign_key "age_range_projekt_phases", "projekt_phases"
  add_foreign_key "ai_chat_messages", "ai_chat_messages", column: "user_message_id", on_delete: :nullify
  add_foreign_key "ai_chat_messages", "ai_chats"
  add_foreign_key "budget_administrators", "administrators"
  add_foreign_key "budget_administrators", "budgets"
  add_foreign_key "budget_investments", "communities"
  add_foreign_key "budget_investments", "sentiments"
  add_foreign_key "budget_valuators", "budgets"
  add_foreign_key "budget_valuators", "valuators"
  add_foreign_key "budgets", "projekt_phases"
  add_foreign_key "budgets", "projekts"
  add_foreign_key "city_street_projekt_phases", "city_streets"
  add_foreign_key "city_street_projekt_phases", "projekt_phases"
  add_foreign_key "dashboard_administrator_tasks", "users"
  add_foreign_key "dashboard_executed_actions", "dashboard_actions", column: "action_id"
  add_foreign_key "dashboard_executed_actions", "proposals"
  add_foreign_key "debates", "projekt_phases"
  add_foreign_key "debates", "projekts"
  add_foreign_key "debates", "sentiments"
  add_foreign_key "deficiency_report_confirmation_popup_answers", "deficiency_report_confirmation_popups", column: "confirmation_popup_id", on_delete: :cascade
  add_foreign_key "deficiency_report_feedback_forms", "deficiency_reports"
  add_foreign_key "deficiency_report_managers", "users"
  add_foreign_key "deficiency_report_officer_group_assignments", "deficiency_report_officer_groups"
  add_foreign_key "deficiency_report_officer_group_assignments", "deficiency_report_officers"
  add_foreign_key "deficiency_report_officers", "users"
  add_foreign_key "deficiency_report_subcategories", "deficiency_report_categories"
  add_foreign_key "deficiency_report_watches", "deficiency_reports"
  add_foreign_key "deficiency_report_watches", "users"
  add_foreign_key "deficiency_reports", "deficiency_report_categories"
  add_foreign_key "deficiency_reports", "deficiency_report_intake_channels"
  add_foreign_key "deficiency_reports", "deficiency_report_officers"
  add_foreign_key "deficiency_reports", "deficiency_report_statuses"
  add_foreign_key "deficiency_reports", "deficiency_report_subcategories"
  add_foreign_key "documents", "users"
  add_foreign_key "failed_census_calls", "poll_officers"
  add_foreign_key "failed_census_calls", "users"
  add_foreign_key "flags", "users"
  add_foreign_key "follows", "users"
  add_foreign_key "formular_answer_documents", "formular_answers"
  add_foreign_key "formular_answer_images", "formular_answers"
  add_foreign_key "formular_answers", "formulars"
  add_foreign_key "formular_fields", "formulars"
  add_foreign_key "formular_follow_up_letter_recipients", "formular_answers"
  add_foreign_key "formular_follow_up_letter_recipients", "formular_follow_up_letters"
  add_foreign_key "formular_follow_up_letters", "formulars"
  add_foreign_key "formulars", "projekt_phases"
  add_foreign_key "geozones_polls", "geozones"
  add_foreign_key "geozones_polls", "polls"
  add_foreign_key "graphql_users", "users"
  add_foreign_key "idea_categories", "idea_officers"
  add_foreign_key "idea_managers", "users"
  add_foreign_key "idea_officers", "users"
  add_foreign_key "ideas", "idea_categories"
  add_foreign_key "ideas", "idea_officers"
  add_foreign_key "ideas", "users", column: "author_id"
  add_foreign_key "identities", "users"
  add_foreign_key "images", "users"
  add_foreign_key "individual_group_values", "individual_groups"
  add_foreign_key "landing_page_manager_assignments", "landing_page_managers"
  add_foreign_key "landing_page_manager_assignments", "site_customization_pages", column: "page_id"
  add_foreign_key "landing_page_managers", "users"
  add_foreign_key "legislation_draft_versions", "legislation_processes"
  add_foreign_key "legislation_processes", "projekt_phases"
  add_foreign_key "legislation_processes", "projekts"
  add_foreign_key "legislation_proposals", "legislation_processes"
  add_foreign_key "locks", "users"
  add_foreign_key "machine_learning_jobs", "users"
  add_foreign_key "managers", "users"
  add_foreign_key "map_layers", "projekts"
  add_foreign_key "map_locations", "registered_address_districts"
  add_foreign_key "masterportal_collections", "projekt_phases"
  add_foreign_key "masterportal_pins", "masterportal_collections"
  add_foreign_key "memos", "users"
  add_foreign_key "moderators", "users"
  add_foreign_key "navbar_items", "navbar_items", column: "parent_id"
  add_foreign_key "navbar_items", "projekts"
  add_foreign_key "newsletters", "recipient_groups"
  add_foreign_key "notifications", "users"
  add_foreign_key "officing_manager_assignments", "officing_managers"
  add_foreign_key "officing_manager_assignments", "projekt_phases"
  add_foreign_key "officing_managers", "users"
  add_foreign_key "ogc_import_runs", "projekt_phases"
  add_foreign_key "organizations", "users"
  add_foreign_key "pending_role_assignments", "users", column: "created_by_id"
  add_foreign_key "poll_answer_map_points", "poll_answers", on_delete: :cascade
  add_foreign_key "poll_answers", "officing_managers"
  add_foreign_key "poll_answers", "poll_questions", column: "question_id"
  add_foreign_key "poll_booth_assignments", "polls"
  add_foreign_key "poll_officer_assignments", "poll_booth_assignments", column: "booth_assignment_id"
  add_foreign_key "poll_partial_results", "poll_booth_assignments", column: "booth_assignment_id"
  add_foreign_key "poll_partial_results", "poll_officer_assignments", column: "officer_assignment_id"
  add_foreign_key "poll_partial_results", "poll_questions", column: "question_id"
  add_foreign_key "poll_partial_results", "users", column: "author_id"
  add_foreign_key "poll_question_answer_videos", "poll_question_answers", column: "answer_id"
  add_foreign_key "poll_question_answers", "poll_questions", column: "question_id"
  add_foreign_key "poll_questions", "poll_question_answers", column: "context_id"
  add_foreign_key "poll_questions", "poll_questions", column: "contexted_clone_of_poll_question_id"
  add_foreign_key "poll_questions", "poll_questions", column: "contextualize_by_poll_question_id"
  add_foreign_key "poll_questions", "polls"
  add_foreign_key "poll_questions", "proposals"
  add_foreign_key "poll_questions", "users", column: "author_id"
  add_foreign_key "poll_recounts", "poll_booth_assignments", column: "booth_assignment_id"
  add_foreign_key "poll_recounts", "poll_officer_assignments", column: "officer_assignment_id"
  add_foreign_key "poll_voters", "officing_managers"
  add_foreign_key "poll_voters", "polls"
  add_foreign_key "polls", "budgets"
  add_foreign_key "polls", "projekt_phases"
  add_foreign_key "polls", "projekts"
  add_foreign_key "projekt_arguments", "projekt_phases"
  add_foreign_key "projekt_evaluations", "projekts"
  add_foreign_key "projekt_event_registrations", "projekt_events"
  add_foreign_key "projekt_event_registrations", "users"
  add_foreign_key "projekt_events", "projekt_phases"
  add_foreign_key "projekt_imports", "projekts"
  add_foreign_key "projekt_imports", "users"
  add_foreign_key "projekt_labelings", "projekt_labels"
  add_foreign_key "projekt_labels", "projekt_phases"
  add_foreign_key "projekt_labels", "projekts"
  add_foreign_key "projekt_livestreams", "projekt_phases"
  add_foreign_key "projekt_manager_assignments", "projekt_managers"
  add_foreign_key "projekt_manager_assignments", "projekts"
  add_foreign_key "projekt_managers", "users"
  add_foreign_key "projekt_notifications", "projekt_phases"
  add_foreign_key "projekt_notifications", "projekts"
  add_foreign_key "projekt_phase_geozones", "geozones"
  add_foreign_key "projekt_phase_geozones", "projekt_phases"
  add_foreign_key "projekt_phase_settings", "projekt_phases"
  add_foreign_key "projekt_phase_stat_questions", "projekt_phases"
  add_foreign_key "projekt_phase_subscriptions", "projekt_phases"
  add_foreign_key "projekt_phase_subscriptions", "users"
  add_foreign_key "projekt_phases", "age_ranges"
  add_foreign_key "projekt_phases", "projekts"
  add_foreign_key "projekt_questions", "projekt_phases"
  add_foreign_key "projekt_settings", "projekts"
  add_foreign_key "projekt_subscriptions", "projekts"
  add_foreign_key "projekt_subscriptions", "users"
  add_foreign_key "projekts", "projekts", column: "parent_id"
  add_foreign_key "projekts", "site_customization_pages", column: "landing_page_id"
  add_foreign_key "proposals", "communities"
  add_foreign_key "proposals", "projekt_phases"
  add_foreign_key "proposals", "projekts"
  add_foreign_key "proposals", "sentiments"
  add_foreign_key "recipient_group_filters", "recipient_groups"
  add_foreign_key "registered_address_district_projekt_phases", "projekt_phases"
  add_foreign_key "registered_address_district_projekt_phases", "registered_address_districts"
  add_foreign_key "registered_address_districts", "idea_officers"
  add_foreign_key "registered_address_street_projekt_phases", "projekt_phases"
  add_foreign_key "registered_address_street_projekt_phases", "registered_address_streets"
  add_foreign_key "registered_addresses", "registered_address_districts"
  add_foreign_key "registered_addresses", "registered_address_streets"
  add_foreign_key "related_content_scores", "related_contents"
  add_foreign_key "related_content_scores", "users"
  add_foreign_key "resource_sentiments", "sentiments"
  add_foreign_key "saved_content_blocks", "users"
  add_foreign_key "sdg_managers", "users"
  add_foreign_key "section_activities", "users"
  add_foreign_key "section_contact_people", "users"
  add_foreign_key "sentiments", "projekt_phases"
  add_foreign_key "site_customization_email_templates", "projekt_phases"
  add_foreign_key "site_customization_pages", "projekts"
  add_foreign_key "user_individual_group_values", "individual_group_values"
  add_foreign_key "user_individual_group_values", "users"
  add_foreign_key "user_resource_criteria", "projekt_phases"
  add_foreign_key "users", "city_streets"
  add_foreign_key "users", "geozones"
  add_foreign_key "users", "registered_addresses"
  add_foreign_key "valuators", "users"
end
