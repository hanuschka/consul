namespace :municipal_plans do
  desc "Archives Vorhaben whose Archivdatum has come, where the instance asked for it"
  task apply_due_archiving: :environment do
    archived = MunicipalPlan.apply_due_archiving!

    puts "archived #{archived.size} Vorhaben"
  end

  desc "Imports the Vorhaben of a legacy export: FILE=... OFFICER_GROUP_ID=... [DRY_RUN=true] " \
       "[REPORT_DIR=...] [BASE_URL=...] [CONTACT_NAME= CONTACT_ROLE= CONTACT_PHONE= CONTACT_EMAIL=]"
  task legacy_import: :environment do
    file = ENV["FILE"].presence || abort("FILE is required")
    group_id = ENV["OFFICER_GROUP_ID"].presence || abort("OFFICER_GROUP_ID is required")
    officer_group = MunicipalPlan::OfficerGroup.find_by(id: group_id) ||
                    abort("No MunicipalPlan::OfficerGroup with id #{group_id}")
    dry_run = ActiveModel::Type::Boolean.new.cast(ENV["DRY_RUN"]) || false

    result = MunicipalPlans::LegacyImport.call(
      file: file,
      officer_group: officer_group,
      dry_run: dry_run,
      report_dir: ENV["REPORT_DIR"],
      base_url: ENV["BASE_URL"],
      contact: { name: ENV["CONTACT_NAME"], role: ENV["CONTACT_ROLE"],
                 phone: ENV["CONTACT_PHONE"], email: ENV["CONTACT_EMAIL"] }
    )

    puts "DRY RUN, nothing saved" if dry_run
    puts "rows read: #{result.rows_read}"
    puts "imported: #{result.mapping.size} " \
         "(published #{result.statuses["published"]}, archived #{result.statuses["archived"]}, " \
         "draft #{result.statuses["draft"]})"
    puts "skipped: #{result.skipped}"
    puts "participation conflicts: #{result.conflicts.size}"
    puts "problems: #{result.problems.size}"
    result.problems.group_by(&:kind).each { |kind, entries| puts "  #{kind}: #{entries.size}" }
    puts "reports: #{result.report_dir}"
  rescue MunicipalPlans::LegacyImport::MissingTopicsError => e
    abort e.message
  end
end
