namespace :generate_data do
  desc "Seed a projekt with one production-scale poll (173 questions with a " \
       "fixed per-question answer distribution, ~20k answers, mixed vote " \
       "types: unique / multiple / multiple_with_weight / rating_scale) for " \
       "testing stats performance. Idempotent / re-runnable. " \
       "Run: bin/rails generate_data:big_poll"
  task big_poll: :environment do
    answer_counts = [
      494, 769, 423, 406, 381, 426, 416, 1188, 0, 417,
      417, 417, 412, 414, 412, 416, 413, 410, 411, 413,
      411, 411, 0, 396, 396, 395, 395, 394, 395, 395,
      393, 394, 393, 393, 393, 700, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      41, 26, 19, 28, 33, 39, 50, 11, 10, 21,
      506, 31, 12, 80, 60, 5, 18, 28, 27, 13,
      95, 24, 15, 62, 158, 399, 0, 44, 31, 21,
      27, 6, 59, 53, 29, 0, 59, 617, 13, 20,
      80, 172, 56, 23, 33, 44, 20, 444, 19, 33,
      75, 11, 39, 21, 92, 15, 27, 70, 31, 27,
      10, 28, 7, 59, 22, 30, 13, 70, 0, 1,
      1, 4, 1, 0, 0, 1, 0, 0, 0, 0,
      1, 0, 2, 0, 1, 1, 0, 1, 1, 0,
      0, 1, 1, 0, 1, 0, 0, 2, 2, 12,
      0, 0, 49
    ]

    projekt_name = "Big Poll Performance Test"
    slug = "big-poll-performance-test"
    poll_name = "Große Bürgerbefragung (Performance-Test)"
    password = "BigPoll2026!"

    # Sized to the largest single-question answer count (1188), so unique and
    # rating questions can draw that many distinct authors.
    pool_size = 1200

    type_cycle = %w[unique multiple rating_scale unique multiple_with_weight]
    unique_option_pool = ["Ja", "Nein", "Teilweise", "Keine Angabe", "Weiß nicht"]
    multiple_options = ["Radwege", "Grünflächen", "ÖPNV", "Spielplätze", "Beleuchtung"]
    weighted_options = ["Bildung", "Verkehr", "Umwelt", "Kultur"]
    rating_options = %w[1 2 3 4 5]

    # Descending weights bias per-option counts so charts show leans, not flat
    # splits; expanded into an index bag for deterministic weighted picks.
    option_weights = [8, 5, 3, 2, 1]
    picks_cycle = [2, 3, 1, 2]
    weight_allocations = [[3, 2], [2, 2, 1], [3, 1, 1], [2, 1, 1, 1]]

    log = ->(msg) { puts "  #{msg}" }

    question_spec = lambda do |index|
      type = type_cycle[index % type_cycle.size]

      case type
      when "unique"
        { type: type, options: unique_option_pool.first(2 + (index % 4)) }
      when "multiple"
        { type: type, options: multiple_options, max_votes: 3 }
      when "multiple_with_weight"
        { type: type, options: weighted_options, max_votes: 5, max_votes_per_answer: 3 }
      when "rating_scale"
        { type: type, options: rating_options,
          min_rating_scale_label: "Trifft gar nicht zu",
          max_rating_scale_label: "Trifft voll zu" }
      end
    end

    ActiveRecord::Base.transaction do
      puts "== Big poll performance seed =="
      now = Time.current

      # -----------------------------------------------------------------------
      # Projekt + page
      # -----------------------------------------------------------------------
      page = SiteCustomization::Page.find_by(slug: slug)
      projekt = page&.projekt

      if projekt
        projekt.update!(name: projekt_name)
        projekt.page.update!(title: projekt_name)
        log.call "Reusing projekt ##{projekt.id}"
      else
        projekt = Projekt.create!(
          name: projekt_name,
          total_duration_start: 6.months.ago,
          total_duration_end: 3.months.from_now,
          color: "#7C3AED",
          icon: "insights"
        )
        projekt.projekt_settings.find_by(key: "projekt_feature.main.activate")&.update!(value: "active")
        projekt.page.update!(status: "published", title: projekt_name,
                             content: "Performance-Testdaten für Umfrage-Statistiken", locale: "de")
        log.call "Created projekt ##{projekt.id} (slug=#{projekt.page.slug})"
      end

      # -----------------------------------------------------------------------
      # Geozones = RegisteredAddress::District (geozone charts are district-driven)
      # -----------------------------------------------------------------------
      city = RegisteredAddress::City.find_or_create_by!(name: "Perfstadt")
      district_names = ["Perf-Bezirk Nord", "Perf-Bezirk Süd", "Perf-Bezirk Ost", "Perf-Bezirk West"]
      districts = district_names.each_with_index.map do |name, i|
        district = RegisteredAddress::District.find_or_create_by!(name: name)
        street = RegisteredAddress::Street.find_or_create_by!(name: "Perfstraße #{i + 1}", plz: "9990#{i}")
        [district, street]
      end
      log.call "Districts (geozones): #{district_names.join(', ')}"

      # -----------------------------------------------------------------------
      # Individual groups (soft clusters) + values
      # -----------------------------------------------------------------------
      membership = IndividualGroup.find_or_create_by!(name: "Mitgliedschaft") do |g|
        g.kind = "soft"
        g.visible = true
      end
      membership_values = ["Verein", "Partei", "Bürgerinitiative"].map do |n|
        IndividualGroupValue.find_or_create_by!(name: n, individual_group: membership)
      end

      interests = IndividualGroup.find_or_create_by!(name: "Interessenschwerpunkt") do |g|
        g.kind = "soft"
        g.visible = true
      end
      interest_values = ["Umwelt", "Verkehr", "Kultur"].map do |n|
        IndividualGroupValue.find_or_create_by!(name: n, individual_group: interests)
      end

      # -----------------------------------------------------------------------
      # Participant pool — bulk-inserted (insert_all skips Devise/AR callbacks;
      # one bcrypt digest is computed once and shared by all seeded users)
      # -----------------------------------------------------------------------
      emails = (1..pool_size).map { |n| sprintf("bigpoll_%04d@consul.dev", n) }
      existing_emails = User.where(email: emails).pluck(:email).to_set
      missing_emails = emails.reject { |email| existing_emails.include?(email) }

      if missing_emails.any?
        encrypted_password = User.new(password: password).encrypted_password
        gender_cycle = %w[female male female male other_gen female male male female male]

        address_rows = missing_emails.each_with_index.map do |_email, i|
          district, street = districts[i % districts.size]
          {
            registered_address_city_id: city.id,
            registered_address_street_id: street.id,
            registered_address_district_id: district.id,
            street_number: (i + 1).to_s,
            created_at: now,
            updated_at: now
          }
        end
        address_ids = RegisteredAddress.insert_all(address_rows).rows.map(&:first)

        user_rows = missing_emails.each_with_index.map do |email, i|
          n = email[/\d+/].to_i
          {
            email: email,
            username: "Perf Bürger:in #{n}",
            encrypted_password: encrypted_password,
            confirmed_at: now,
            verified_at: now,
            residence_verified_at: now,
            gender: gender_cycle[n % gender_cycle.size],
            date_of_birth: (18 + (n % 62)).years.ago,
            registered_address_id: address_ids[i],
            created_at: now,
            updated_at: now
          }
        end
        User.insert_all(user_rows)
      end

      pool_ids = User.where(email: emails).order(:email).pluck(:id)
      log.call "Participant pool: #{pool_ids.size} users (#{missing_emails.size} new)"

      group_rows = []
      pool_ids.each_with_index do |user_id, i|
        mi = i % 4
        ii = (i + 2) % 4

        if mi < 3
          group_rows << { user_id: user_id, created_at: now, updated_at: now,
                          individual_group_value_id: membership_values[mi].id }
        end

        if ii < 3
          group_rows << { user_id: user_id, created_at: now, updated_at: now,
                          individual_group_value_id: interest_values[ii].id }
        end
      end
      group_rows.each_slice(5000) { |slice| UserIndividualGroupValue.insert_all(slice) }

      # -----------------------------------------------------------------------
      # Voting phase + poll
      # -----------------------------------------------------------------------
      voting_phase = projekt.projekt_phases.find_by(type: "ProjektPhase::VotingPhase")

      if voting_phase.nil?
        voting_phase = ProjektPhase::VotingPhase.create!(
          projekt: projekt, active: true, frontend_visibility: true,
          start_date: 2.months.ago, end_date: 1.month.ago, phase_tab_name: "Abstimmung"
        )
      end

      voting_phase.update!(active: true, frontend_visibility: true)
      voting_phase.settings.find_or_initialize_by(key: "feature.general.public_kpi_stats").update!(value: "active")

      poll = voting_phase.polls.order(:id).first
      poll ||= voting_phase.polls.create!(name: poll_name, slug: "#{slug}-poll")
      poll.update!(
        name: poll_name, starts_at: 2.months.ago, ends_at: 1.month.ago,
        results_enabled: true, stats_enabled: true, published: true
      )

      # -----------------------------------------------------------------------
      # Questions (mixed vote types) + options
      # -----------------------------------------------------------------------
      author = User.find(pool_ids.first)
      created_questions = 0

      questions = answer_counts.each_with_index.map do |_count, i|
        spec = question_spec.call(i)
        title = "Performance-Testfrage #{i + 1}"
        question = poll.questions.find_by(title: title)

        if question.nil?
          question = Poll::Question.new(
            poll: poll, author: author, title: title, given_order: i + 1
          )
          question.votation_type = VotationType.new(
            vote_type: spec[:type],
            max_votes: spec[:max_votes],
            max_votes_per_answer: spec[:max_votes_per_answer],
            min_rating_scale_label: spec[:min_rating_scale_label],
            max_rating_scale_label: spec[:max_rating_scale_label]
          )
          question.save!

          spec[:options].each_with_index do |option_title, oi|
            Poll::Question::Answer.create!(question: question, title: option_title, given_order: oi + 1)
          end

          created_questions += 1
        end

        [question, spec]
      end
      log.call "Questions: #{questions.size} total (#{created_questions} new, " \
               "#{answer_counts.count(&:zero?)} without answers)"

      # -----------------------------------------------------------------------
      # Answers — deterministic distribution, bulk-inserted. A question that
      # already has answers is skipped, keeping the task re-runnable.
      # -----------------------------------------------------------------------
      window_seconds = 30 * 24 * 3600
      phase_start = voting_phase.start_date.to_time
      answered_question_ids =
        Poll::Answer
          .where(question_id: questions.map { |question, _spec| question.id })
          .distinct
          .pluck(:question_id)
          .to_set

      answer_rows = []
      used_author_ids = Set.new

      questions.each_with_index do |(question, spec), qi|
        count = answer_counts[qi]

        next if count.zero?
        next if answered_question_ids.include?(question.id)

        options = spec[:options]
        bag =
          option_weights
            .first(options.size)
            .each_with_index
            .flat_map { |weight, oi| Array.new(weight, oi) }
        offset = (qi * 37) % pool_ids.size
        step = [window_seconds / count, 1].max

        add_row = lambda do |author_id, option_index, row_index, answer_weight|
          ts = phase_start + (row_index * step)
          used_author_ids << author_id
          answer_rows << {
            question_id: question.id,
            author_id: author_id,
            answer: options[option_index],
            answer_weight: answer_weight,
            created_at: ts,
            updated_at: ts
          }
        end

        case spec[:type]
        when "unique", "rating_scale"
          count.times do |j|
            author_id = pool_ids[(offset + j) % pool_ids.size]
            add_row.call(author_id, bag[(j * 7 + qi) % bag.size], j, 1)
          end
        when "multiple"
          remaining = count
          vi = 0

          while remaining > 0
            picks = [picks_cycle[vi % picks_cycle.size], remaining, options.size].min
            author_id = pool_ids[(offset + vi) % pool_ids.size]
            start_option = bag[(vi + qi) % bag.size]

            picks.times do |slot|
              add_row.call(author_id, (start_option + slot) % options.size,
                           count - remaining + slot, 1)
            end

            remaining -= picks
            vi += 1
          end
        when "multiple_with_weight"
          remaining = count
          vi = 0

          while remaining > 0
            allocation = weight_allocations[vi % weight_allocations.size]
            slots = [allocation.size, remaining, options.size].min
            author_id = pool_ids[(offset + vi) % pool_ids.size]
            start_option = bag[(vi + qi) % bag.size]

            slots.times do |slot|
              add_row.call(author_id, (start_option + slot) % options.size,
                           count - remaining + slot, allocation[slot])
            end

            remaining -= slots
            vi += 1
          end
        end
      end

      answer_rows.each_slice(5000) { |slice| Poll::Answer.insert_all(slice) }
      log.call "Answers: #{answer_rows.size} inserted (target sum #{answer_counts.sum})"

      # -----------------------------------------------------------------------
      # Voters (one per distinct participating author)
      # -----------------------------------------------------------------------
      existing_voter_ids = poll.voters.pluck(:user_id).to_set
      new_voter_ids = used_author_ids.sort.reject { |id| existing_voter_ids.include?(id) }
      voter_step = [window_seconds / [new_voter_ids.size, 1].max, 1].max

      voter_rows = new_voter_ids.each_with_index.map do |user_id, i|
        ts = phase_start + (i * voter_step)
        { poll_id: poll.id, user_id: user_id, origin: "web", created_at: ts, updated_at: ts }
      end
      voter_rows.each_slice(5000) { |slice| Poll::Voter.insert_all(slice) }

      # Poll stats are cached keyed on the stats version timestamp — touch it so
      # freshly seeded data isn't hidden behind a stale cache entry.
      poll.stats_version&.touch
      log.call "Voters: #{poll.voters.count} total (#{voter_rows.size} new)"

      puts
      puts "== Next step =="
      base = Setting["url"].to_s.chomp("/")
      log.call "Frontend:  #{base}/#{projekt.page.slug}"
      log.call "Adm eval:  #{base}/adm/projekts/#{projekt.id}/evaluation"
      log.call "Seed users password: #{password}"
    end

    puts "Done."
  end
end
