namespace :maintenance do
  desc "Reverify users"
  task reverify_users: :environment do
    ApplicationLogger.new.info "Reverifying users"
    VerificationServices::UsersReverifier.call
  end

  # Read-only, so it is safe on any environment and answers the question the
  # backfill task would act on. Here rather than in one_time_tasks because the
  # state it looks for can come back: any new path that attaches a generated
  # picture without marking it produces exactly this.
  desc "Report generated pictures published without the AI marker in their bytes"
  task audit_ai_image_marking: :environment do
    if !ExiftoolCommand.available?
      abort("exiftool is not available (#{ExiftoolCommand.runtime_status}) — nothing could be read")
    end

    report = Images::AuditAiMarkingService.call

    puts "checked: #{report.checked}"
    puts "marked: #{report.marked}"
    puts "unmarked: #{report.unmarked}"
    puts "unreadable: #{report.unreadable}"

    if report.unmarked.positive?
      puts "unmarked image ids: #{report.unmarked_ids.join(", ")}"
      puts "repair with: bin/rails one_time_tasks:backfill_ai_image_marking"
    end
  end
end
