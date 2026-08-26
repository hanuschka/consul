namespace :machine_translation do
  desc "Estimate the DeepL characters needed to backfill a target locale"
  task :estimate, [:locale] => :environment do |_task, args|
    locale = MachineTranslation::Tasks.validate_locale!(args[:locale])
    total = 0

    MachineTranslation.translatable_models.each do |model|
      characters = 0
      records = 0

      MachineTranslation::Tasks.pending_records(model, locale) do |record, source_row|
        records += 1
        characters += MachineTranslation::Tasks.characters_in(model, source_row)
      end

      next if records.zero?

      total += characters
      puts format("  %-28s %6d records %10d chars", model.name, records, characters)
    end

    puts format("  %-28s %6s %10d chars (~EUR %.2f at 22/1M)", "TOTAL for #{locale}", "", total,
                total / 1_000_000.0 * 22)
  end

  desc "Enqueue DeepL translations for existing content in a target locale"
  task :backfill, [:locale, :limit] => :environment do |_task, args|
    locale = MachineTranslation::Tasks.validate_locale!(args[:locale])

    unless MachineTranslation.enabled?
      abort "machine translation is disabled (needs a DeepL key and " \
            "#{MachineTranslation::SETTING_KEY})"
    end

    limit = args[:limit].presence&.to_i
    enqueued = 0

    MachineTranslation.translatable_models.each do |model|
      model_enqueued = 0

      MachineTranslation::Tasks.pending_records(model, locale) do |record, source_row|
        break if limit && enqueued >= limit
        next if MachineTranslation::Tasks.pending_translation?(record, locale)

        remote_translation = RemoteTranslation.new(remote_translatable: record, locale: locale)
        remote_translation.source_locale = source_row.locale
        remote_translation.backfill = true

        next unless remote_translation.save

        enqueued += 1
        model_enqueued += 1
      end

      puts format("  %-28s %6d enqueued", model.name, model_enqueued) if model_enqueued.positive?
    end

    puts "  enqueued #{enqueued} translations into #{locale}"
    puts "  run machine_translation:clear_cache once the queue has drained"
  end

  desc "Clear the fragment cache after a backfill (backfill writes skip the parent touch)"
  task clear_cache: :environment do
    Rails.cache.clear
    puts "  cache cleared"
  end
end
