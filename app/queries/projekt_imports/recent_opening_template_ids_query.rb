# The templates the latest imported pages open with, newest import first. A new
# import is not offered them, so it cannot open the way a recent one did.
#
# Neither source knows every import. A projekt keeps its layout for good, while
# a completed import is purged after 30 days. An import that is analysed but
# not submitted yet has no projekt, and without it several documents uploaded
# back to back would all be analysed against the same history.
class ProjektImports::RecentOpeningTemplateIdsQuery < ApplicationQuery
  HISTORY_SIZE = 5
  AWAITING_SUBMIT_STATUSES = %w[chatting submitting].freeze
  OPENING_TEMPLATE_ID_SQL = "ai_result -> 'content_blocks' -> 0 -> 'template_id'".freeze

  def call
    (submitted_openings + awaiting_submit_openings)
      .sort_by { |imported_at, _template_id| imported_at }
      .last(HISTORY_SIZE)
      .reverse
      .map { |_imported_at, template_id| template_id }
      .uniq
  end

  private

    # Copies never carry the column: a copy keeps its source's layout on
    # purpose and is not an import.
    def submitted_openings
      Projekt
        .where("cardinality(imported_content_block_template_ids) > 0")
        .order(created_at: :desc)
        .limit(HISTORY_SIZE)
        .pluck(:created_at, Arel.sql("imported_content_block_template_ids[1]"))
    end

    # Blocks keep their template id until the submit renders them to HTML, which
    # is also when the sequence moves onto the projekt, so no import is counted
    # twice.
    def awaiting_submit_openings
      ProjektImport
        .where(status: AWAITING_SUBMIT_STATUSES)
        .where("jsonb_typeof(#{OPENING_TEMPLATE_ID_SQL}) = 'number'")
        .order(created_at: :desc)
        .limit(HISTORY_SIZE)
        .pluck(:created_at, Arel.sql("(#{OPENING_TEMPLATE_ID_SQL})::text::numeric::integer"))
    end
end
