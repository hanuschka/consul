namespace :kern do
  namespace :i18n do
    def kern_task
      require "i18n/tasks"
      I18n::Tasks::BaseTask.new(config_file: "config/i18n-tasks-kern.yml")
    end

    desc "Show keys present in kern/de but missing in kern/en"
    task missing: :environment do
      diff = kern_task.missing_diff_tree("en", "de")
      puts "#{diff.leaves.count} keys present in kern/de are missing in kern/en"

      if diff.leaves.count.zero?
        puts "✓ kern/en is in parity with kern/de"
      else
        diff.leaves.each do |node|
          puts "  #{node.full_key}"
        end
      end
    end

    desc "Summary: counts only, no key listing"
    task stats: :environment do
      t = kern_task
      puts "kern/de has #{t.data_forest([:de]).leaves.count} keys"
      puts "kern/en has #{t.data_forest([:en]).leaves.count} keys"
      puts "missing in kern/en (vs kern/de): #{t.missing_diff_tree('en', 'de').leaves.count}"
    end

    desc "Translations in kern/en that are identical to kern/de (likely untranslated)"
    task eq_base: :environment do
      eq = kern_task.eq_base_keys(locale: "en", base_locale: "de")
      puts "#{eq.leaves.count} en keys have the same value as de (possibly untranslated)"
      eq.leaves.each { |n| puts "  #{n.full_key}" }
    end
  end
end
