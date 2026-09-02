namespace :stats do
  desc "Generates stats which are not cached yet"
  task generate: :environment do
    logger = ApplicationLogger.new
    logger.info "Updating budget and poll stats"

    admin_user = Administrator.first&.user

    if admin_user.blank?
      logger.info "No administrator found, skipping stats generation"
      next
    end

    admin_ability = Ability.new(admin_user)

    # One unstatisticable record must not stop the remaining ones from being
    # regenerated, so failures are reported and skipped rather than raised.
    generate_stats = lambda do |record, ability_action, stats_class|
      return unless admin_ability.can?(ability_action, record)

      stats_class.new(record).generate
      print "."
    rescue StandardError => e
      print "!"
      logger.error "Failed to generate stats for #{record.class}##{record.id}: #{e.class}: #{e.message}"
      Sentry.capture_exception(e, extra: { record: "#{record.class}##{record.id}" }) if defined?(Sentry)
    end

    Budget.find_each { |budget| generate_stats.call(budget, :read_stats, Budget::Stats) }
    Poll.find_each { |poll| generate_stats.call(poll, :stats, Poll::Stats) }
  end

  desc "Expires stats cache"
  task expire_cache: :environment do
    [Budget, Poll].each do |model_class|
      model_class.find_each { |record| record.find_or_create_stats_version.touch }
    end
  end

  desc "Deletes stats cache and generates it again"
  task regenerate: [:expire_cache, :generate]
end
