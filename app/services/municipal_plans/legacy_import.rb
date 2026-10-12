require "csv"

module MunicipalPlans
  # Imports the Vorhaben of the legacy Vorhabenliste export. Every row is matched by its legacy id,
  # so a second run overwrites the first instead of adding to it.
  class LegacyImport < ApplicationService
    class MissingTopicsError < StandardError; end

    Problem = Struct.new(:legacy_id, :title, :kind, :message, keyword_init: true)
    Result = Struct.new(:rows_read, :statuses, :skipped, :problems, :conflicts, :mapping, :report_dir,
                        keyword_init: true)

    OPEN_ENDED_YEAR = 2999
    SESSIONNET_HOST = /(\A|\.)sessionnet\.(owl-it|jena)\.de\z/i
    DEFAULT_CONTACT = { name: "Zentrale Stelle – bitte ersetzen", role: nil, phone: nil, email: nil }.freeze

    def initialize(file:, officer_group:, dry_run: false, report_dir: nil, base_url: nil, contact: {})
      @file = file
      @officer_group = officer_group
      @dry_run = dry_run
      @report_dir = Pathname(report_dir.presence || Rails.root.join("tmp/municipal_plans_legacy_import"))
      @base_url = base_url
      @contact = DEFAULT_CONTACT.merge(contact.compact_blank)
      @problems = []
      @conflicts = []
      @mapping = []
      @statuses = Hash.new(0)
      @skipped = 0
    end

    def call
      rows = CSV.read(file, col_sep: "\t", quote_char: "'", headers: true, encoding: "bom|utf-8")
      topics = resolve_topics(rows)
      districts = district_index
      report_duplicates(rows)

      # Around the transaction: the translations touch the Vorhaben on commit, and audited records a touch.
      without_auditing do
        MunicipalPlan.transaction(requires_new: true) do
          activity_floor = SectionActivity.maximum(:id).to_i
          rows.each { |row| import(row, topics, districts) }

          discard_activity_since(activity_floor)

          raise ActiveRecord::Rollback if dry_run
        end
      end

      write_reports
      Result.new(rows_read: rows.size, statuses: statuses, skipped: skipped, problems: problems,
                 conflicts: conflicts, mapping: mapping, report_dir: report_dir)
    end

    private

      attr_reader :file, :officer_group, :dry_run, :report_dir, :base_url, :contact,
                  :problems, :conflicts, :mapping, :statuses, :skipped

      def import(row, topics, districts)
        legacy_id = row["id"].to_s.strip
        title = MunicipalPlans::LegacyImport::Html.single_line(row["title"])

        if title.blank?
          @skipped += 1
          return problem(legacy_id, row["title"], :blank_title, "no title, row skipped")
        end

        report_row_notes(row, legacy_id, title)

        block = MunicipalPlans::LegacyImport::TextBlock.new(row["rel_derivate_absaetze"])
        report_block(block, row, legacy_id, title)

        status, archive_on = status_for(row)
        dates = dates_for(row, archive_on, legacy_id, title)

        # A savepoint per row: a Vorhaben that fails on a re-run keeps its links and assignments.
        MunicipalPlan.transaction(requires_new: true) do
          plan = MunicipalPlan.find_or_initialize_by(legacy_id: legacy_id)
          existed = plan.persisted?
          previous_version = plan.version if existed
          reset_associations(plan) if existed

          Globalize.with_locale(I18n.default_locale) do
            plan.assign_attributes(plan_attributes(row, title, block, archive_on))
          end
          assign_topics(plan, row, topics)
          assign_districts(plan, row, districts, legacy_id, title)
          assign_links(plan, row, legacy_id, title)

          plan.status = block.split? ? status : "draft"
          raise ActiveRecord::Rollback unless save_with_fallback(plan, status, legacy_id, title)

          apply_dates(plan, row, dates, previous_version)
          statuses[plan.status] += 1
          mapping << { legacy_id: legacy_id, title: title, plan: plan, existed: existed }
        end
      end

      def save_with_fallback(plan, status, legacy_id, title)
        return true if plan.save

        if plan.status != "draft"
          reasons = plan.errors.full_messages.join(" ")
          plan.status = "draft"

          if plan.save
            problem(legacy_id, title, :draft_fallback, "imported as draft, not #{status}: #{reasons}")
            return true
          end
        end

        problem(legacy_id, title, :invalid, "not imported: #{plan.errors.full_messages.join(" ")}")
        false
      end

      def plan_attributes(row, title, block, archive_on)
        fields = block.fields

        {
          title: title,
          short_description: MunicipalPlans::LegacyImport::Html.to_plain_text(row["txt_text"]),
          further_information: fields[:further_information],
          last_resolution: fields[:last_resolution],
          processing_status: fields[:processing_status],
          next_steps: fields[:next_steps],
          costs: fields[:costs],
          formal_participation_reason: fields[:formal_participation_reason],
          informal_participation_reason: fields[:informal_participation_reason],
          formal_participation: on?(row["flag_buergerbeteiligung_formell"]),
          informal_participation: on?(row["flag_buergerbeteiligung_informell"]),
          archive_on: archive_on,
          responsible: officer_group,
          contact_name: contact[:name],
          contact_role: contact[:role],
          contact_phone: contact[:phone],
          contact_email: contact[:email],
          submitted_at: nil
        }
      end

      def reset_associations(plan)
        plan.links.destroy_all
        plan.topic_assignments.destroy_all
        plan.district_assignments.destroy_all
        plan.reload
      end

      def status_for(row)
        date = parse_date(row["archive_date"])

        if date.nil? || date.year >= OPEN_ENDED_YEAR
          ["published", nil]
        elsif date < Date.current
          ["archived", date]
        else
          ["published", date]
        end
      end

      def dates_for(row, archive_on, legacy_id, title)
        changed_on = parse_date(row["change_date_manuel"])
        return { created_on: changed_on, content_updated_on: changed_on } if changed_on
        return { created_on: archive_on, content_updated_on: archive_on } if archive_on&.past?

        problem(legacy_id, title, :missing_date,
                "no change or archive date: created at the time of the import")
        { created_on: nil, content_updated_on: nil }
      end

      # Written past the callbacks: a save would restamp the Aktualisierungsdatum and the
      # Versionsnummer, and the Vorhaben would carry "neu" or "aktualisiert" right after the import.
      def apply_dates(plan, row, dates, previous_version)
        created_at = dates[:created_on]&.in_time_zone
        columns = { content_updated_at: dates[:content_updated_on] }
        columns[:created_at] = created_at if created_at
        columns[:version] = row["txt_versionsnummer"].presence&.strip || previous_version || plan.version
        columns[:released_at] = plan.draft? ? nil : (created_at || plan.released_at || Time.current)

        plan.update_columns(columns)
      end

      def assign_topics(plan, row, topics)
        names = split_list(row["rel_vorhabensliste_kategorien"])

        names.map { |name| topics.fetch(normalize_name(name)) }.uniq.each do |topic|
          plan.topic_assignments.build(topic: topic)
        end
      end

      def assign_districts(plan, row, districts, legacy_id, title)
        matched = split_list(row["rel_ortschaften"]).filter_map do |name|
          candidates = districts[normalize_name(name)] || []
          next candidates.first if candidates.size == 1

          if candidates.empty?
            problem(legacy_id, title, :unmatched_district, "Ortsteil not found: #{name}")
          else
            problem(legacy_id, title, :ambiguous_district,
                    "Ortsteil ambiguous (#{candidates.size} matches): #{name}")
          end
          nil
        end.uniq

        if matched.size > MunicipalPlan::MAX_DISTRICTS
          problem(legacy_id, title, :too_many_districts,
                  "more than #{MunicipalPlan::MAX_DISTRICTS} Ortsteile, only the first ones kept")
          matched = matched.first(MunicipalPlan::MAX_DISTRICTS)
        end

        matched.each { |district| plan.district_assignments.build(district: district) }
      end

      def assign_links(plan, row, legacy_id, title)
        row["rel_derivate_links"].to_s.split(/,(?=\s*\S?https?:)/i).map(&:strip).compact_blank
                                 .each_with_index do |url, index|
          url = clean_url(url, legacy_id, title)
          plan.links.build(url: url, title: link_title(url, legacy_id, title), given_order: index + 1)
        end
      end

      def clean_url(url, legacy_id, title)
        cleaned = url.sub(/\A[^a-z]+(?=https?:)/i, "")
        if cleaned != url
          problem(legacy_id, title, :link_cleaned, "stray characters removed before link: #{url}")
        end
        cleaned
      end

      def link_title(url, legacy_id, title)
        uri = URI.parse(url)

        if uri.host.to_s.match?(SESSIONNET_HOST)
          number = CGI.parse(uri.query.to_s)["__kvonr"]&.first
          ["Beschlussvorlage", number, "(Ratsinformationssystem)"].compact_blank.join(" ")
        elsif uri.path.to_s.match?(/\.pdf\z/i)
          "Dokument #{URI::DEFAULT_PARSER.unescape(File.basename(uri.path, ".*"))} (PDF)"
        else
          uri.host.presence || url
        end
      rescue URI::InvalidURIError
        problem(legacy_id, title, :invalid_link, "link is not a valid URL: #{url}")
        url
      end

      def resolve_topics(rows)
        index = MunicipalPlan::Topic.unscoped.includes(:translations).each_with_object({}) do |topic, found|
          topic.translations.each { |translation| found[normalize_name(translation.name)] ||= topic }
        end

        names = rows.flat_map { |row| split_list(row["rel_vorhabensliste_kategorien"]) }.uniq
        missing = names.reject { |name| index.key?(normalize_name(name)) }
        return index if missing.empty?

        raise MissingTopicsError, "Missing Themen, nothing imported: #{missing.sort.join(", ")}"
      end

      def district_index
        RegisteredAddress::District.unscoped.to_a.group_by { |district| normalize_name(district.name) }
      end

      def report_duplicates(rows)
        rows.group_by { |row| MunicipalPlans::LegacyImport::Html.single_line(row["title"])&.downcase }
            .each do |title, group|
          next if title.blank? || group.size < 2

          ids = group.map { |row| row["id"] }
          group.each do |row|
            problem(row["id"], MunicipalPlans::LegacyImport::Html.single_line(row["title"]), :duplicate_title,
                    "possible duplicate, same title as #{(ids - [row["id"]]).join(", ")}")
          end
        end
      end

      def report_row_notes(row, legacy_id, title)
        if row["status"].present?
          problem(legacy_id, title, :legacy_status, "status \"#{row["status"]}\" ignored")
        end

        flag = on?(row["flag_buergerbeteiligung"])
        formal = on?(row["flag_buergerbeteiligung_formell"])
        informal = on?(row["flag_buergerbeteiligung_informell"])
        return if flag == (formal || informal)

        conflicts << { legacy_id: legacy_id, title: title, flag: row["flag_buergerbeteiligung"],
                       formell: row["flag_buergerbeteiligung_formell"],
                       informell: row["flag_buergerbeteiligung_informell"] }
      end

      def report_block(block, row, legacy_id, title)
        block.unknown_headings.each do |heading|
          problem(legacy_id, title, :unknown_heading,
                  "unknown sub-heading #{heading}: not split, imported as draft")
        end

        block.notes.each do |message|
          problem(legacy_id, title, :unparsed_participation,
                  "#{message}: moved to further information, reasons left empty")
        end

        { formal: "flag_buergerbeteiligung_formell", informal: "flag_buergerbeteiligung_informell" }
          .each do |kind, column|
          stated = block.participation[kind]
          next if stated.nil? || stated == on?(row[column])

          problem(legacy_id, title, :participation_text_mismatch,
                  "Bürgerbeteiligung #{kind == :formal ? "formell" : "informell"}: text says " \
                  "#{stated ? "Ja" : "Nein"}, column says #{row[column]} (column kept)")
        end
      end

      def write_reports
        FileUtils.mkdir_p(report_dir)

        write_csv("problems.csv", %w[legacy_id title problem],
                  problems.map { |entry| [entry.legacy_id, entry.title, entry.message] })
        write_csv("participation_conflicts.csv", %w[legacy_id title flag formell informell],
                  conflicts.map { |entry| entry.values_at(:legacy_id, :title, :flag, :formell, :informell) })
        write_csv("mapping.csv", %w[legacy_id title new_id new_url],
                  mapping.map { |entry| mapping_row(entry) })
      end

      def mapping_row(entry)
        return [entry[:legacy_id], entry[:title], nil, nil] if dry_run && !entry[:existed]

        [entry[:legacy_id], entry[:title], entry[:plan].id,
         Rails.application.routes.url_helpers.municipal_plan_url(entry[:plan], **url_options)]
      end

      def write_csv(name, headers, rows)
        CSV.open(report_dir.join(name), "w") do |csv|
          csv << headers
          rows.each { |row| csv << row }
        end
      end

      def url_options
        return UrlOptions.default.symbolize_keys if base_url.blank?

        uri = URI.parse(base_url)
        options = { host: uri.host, protocol: uri.scheme }
        options[:port] = uri.port unless uri.port == uri.default_port
        options
      end

      def discard_activity_since(activity_floor)
        plan_ids = mapping.map { |entry| entry[:plan].id }

        SectionActivity.where(trackable_type: "MunicipalPlan", trackable_id: plan_ids)
                       .where("id > ?", activity_floor).delete_all
      end

      def without_auditing(&block)
        MunicipalPlan.without_auditing do
          MunicipalPlan.translation_class.without_auditing(&block)
        end
      end

      def problem(legacy_id, title, kind, message)
        problems << Problem.new(legacy_id: legacy_id, title: title, kind: kind, message: message)
      end

      def split_list(value)
        value.to_s.split(",").map(&:squish).compact_blank
      end

      def normalize_name(name)
        name.to_s.squish.gsub(%r{\s*/\s*}, "/").downcase
      end

      def on?(value)
        value.to_s.strip.casecmp?("on")
      end

      def parse_date(value)
        Date.parse(value.to_s) if value.present?
      rescue ArgumentError
        nil
      end
  end
end
