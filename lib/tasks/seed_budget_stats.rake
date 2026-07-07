namespace :demo do
  desc "Seed a budget-stats demo projekt with a budget phase, budget, 5 " \
       "investments (full data), feedback comments, supports, ballots and " \
       "demographically rich participants (gender/age/geozone/individual-group " \
       "clusters) to exercise the budget-phase Kennzahlen (key_metrics) stats. " \
       "Idempotent / re-runnable. Run: bin/rails demo:budget_stats"
  task budget_stats: :environment do
    projekt_name = "Budget stats demo"
    slug = "budget-stats-demo"
    password = "DemoBudget2026!"

    log = ->(msg) { puts "  #{msg}" }

    ActiveRecord::Base.transaction do
      puts "== Budget stats demo seed =="

      # -----------------------------------------------------------------------
      # Projekt + page
      # -----------------------------------------------------------------------
      page = SiteCustomization::Page.find_by(slug: slug)
      projekt = page&.projekt

      if projekt
        log.call "Reusing projekt ##{projekt.id}"
      else
        projekt = Projekt.create!(
          name: projekt_name,
          total_duration_start: 1.month.ago,
          total_duration_end: 2.months.from_now,
          color: "#00AA02",
          icon: "euro_symbol"
        )
        projekt.projekt_settings.find_by(key: "projekt_feature.main.activate")&.update!(value: "active")
        projekt.page.update!(status: "published", title: projekt_name,
                             content: "Bürgerhaushalt – Testdaten", locale: "de")
        log.call "Created projekt ##{projekt.id} (slug=#{projekt.page.slug})"
      end

      # -----------------------------------------------------------------------
      # Budget phase (auto-creates budget + group + heading), enable public KPI
      # -----------------------------------------------------------------------
      phase = projekt.budget_phases.first
      unless phase
        phase = ProjektPhase::BudgetPhase.create!(
          projekt: projekt,
          active: true,
          frontend_visibility: true,
          start_date: 1.month.ago,
          end_date: 2.months.from_now,
          phase_tab_name: "Bürgerhaushalt"
        )
        log.call "Created budget phase ##{phase.id}"
      end
      phase.update!(active: true, frontend_visibility: true)
      phase.settings.find_or_initialize_by(key: "feature.general.public_kpi_stats").update!(value: "active")
      phase.settings.find_or_initialize_by(key: "feature.resource.show_comments").update!(value: "active")

      budget = phase.reload.budget
      budget.update!(phase: "finished", results_enabled: true, stats_enabled: true, published: true)
      heading = budget.heading
      group = budget.group
      heading.update!(price: 5_000_000, population: 120_000)

      # Budget#current_phase is driven by Budget::Phase date windows (not the
      # `phase` column). Shift all windows into the past and make "finished"
      # span today so current_phase == finished → read_stats / read_results pass.
      today = Date.current
      budget.phases.order(:id).each_with_index do |ph, i|
        ph.update_columns(enabled: true,
                          starts_at: today - (9 - i).months,
                          ends_at: today - (8 - i).months)
      end
      budget.phases.finished.update_columns(starts_at: today - 3.days, ends_at: today + 3.days)
      budget.reload
      log.call "Budget ##{budget.id} current_phase=#{budget.current_phase.kind} heading=##{heading.id}"

      # -----------------------------------------------------------------------
      # Geozones = RegisteredAddress::District on this app (the geozone charts
      # are driven by districts, since RegisteredAddress::District.present? is
      # truthy). Build City + one Street/District pair per district.
      # -----------------------------------------------------------------------
      city = RegisteredAddress::City.find_or_create_by!(name: "Musterstadt")
      district_names = ["Stadtteil Nord", "Stadtteil Süd", "Stadtteil Ost", "Stadtteil West"]
      districts = district_names.each_with_index.map do |name, i|
        district = RegisteredAddress::District.find_or_create_by!(name: name)
        street = RegisteredAddress::Street.find_or_create_by!(name: "Teststraße #{name}", plz: "8000#{i}")
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
      log.call "Clusters: Mitgliedschaft(#{membership_values.map(&:name).join('/')}), " \
               "Interessenschwerpunkt(#{interest_values.map(&:name).join('/')})"

      # -----------------------------------------------------------------------
      # Participants with full demographic data
      # [gender, age, geozone_index, membership_index(nil ok), interest_index(nil ok)]
      # -----------------------------------------------------------------------
      people = [
        ["female",    18, 0, 0, 0], ["male",      22, 1, nil, 1], ["female",    24, 2, 1, 0],
        ["male",      27, 3, 2, 2], ["other_gen", 29, 0, 0, 1], ["female",    31, 1, nil, 0],
        ["male",      34, 2, 1, 1], ["female",    37, 3, 0, 2], ["male",      41, 0, 2, nil],
        ["female",    44, 1, 1, 0], ["other_gen", 48, 2, nil, 1], ["male",      52, 3, 0, 2],
        ["female",    57, 0, 1, 0], ["male",      61, 1, 2, 1], ["female",    66, 2, 0, nil],
        ["male",      71, 3, 1, 2], ["other_gen", 76, 0, nil, 0], ["female",    83, 1, 0, 1]
      ]

      users = people.each_with_index.map do |(gender, age, gz, mi, ii), idx|
        email = "budget_stats_demo_#{idx + 1}@consul.dev"
        district, street = districts[gz]

        user = User.find_or_initialize_by(email: email)
        address = user.registered_address || RegisteredAddress.new
        address.update!(
          registered_address_city: city,
          registered_address_street: street,
          district: district,
          street_number: (idx + 1).to_s
        )

        if user.new_record?
          user.password = password
          user.password_confirmation = password
        end
        user.assign_attributes(
          username: "Demo Bürger:in #{idx + 1}",
          terms_data_storage: "1",
          terms_data_protection: "1",
          terms_general: "1",
          confirmed_at: Time.current,
          verified_at: Time.current,
          residence_verified_at: Time.current,
          public_activity: true,
          gender: gender,
          date_of_birth: age.years.ago,
          registered_address: address
        )
        user.save!

        assign_value = lambda do |value|
          UserIndividualGroupValue.find_or_create_by!(user: user, individual_group_value: value)
        end
        assign_value.call(membership_values[mi]) if mi
        assign_value.call(interest_values[ii]) if ii

        user
      end
      log.call "Participants: #{users.size} (M/F/D + varied ages, 4 geozones, 2 clusters)"

      # -----------------------------------------------------------------------
      # Investments (full data) + feedback comments
      # -----------------------------------------------------------------------
      investment_specs = [
        {
          title: "Fahrradstraße entlang des Flusses",
          description: "Eine durchgehende, sichere Fahrradstraße entlang des Flusses vom " \
                       "Zentrum bis zum Stadtrand. Sie verbindet Wohnviertel mit der " \
                       "Innenstadt und entlastet die Hauptverkehrsachsen.",
          price: 850_000, feasibility: "feasible", selected: true, winner: true,
          physical_votes: 40,
          comments: [
            "Endlich! Ich fahre täglich mit dem Rad in die Arbeit und die aktuelle Route ist gefährlich.",
            "Bitte auch an Beleuchtung und Winterdienst denken, sonst ist die Straße im Winter nutzlos.",
            "Super Idee, aber wie wird das mit den Fußgängern am Flussufer geregelt?"
          ]
        },
        {
          title: "Neue Spielplätze im Stadtpark",
          description: "Sanierung der bestehenden Spielplätze und Bau von zwei neuen, " \
                       "barrierefreien Spielbereichen im Stadtpark – inklusive Schattenplätzen " \
                       "und Sitzgelegenheiten für Eltern.",
          price: 320_000, feasibility: "feasible", selected: true, winner: false,
          physical_votes: 18,
          comments: [
            "Als Mutter von zwei Kindern finde ich das großartig. Die alten Geräte sind marode.",
            "Barrierefreiheit ist wichtig – danke, dass daran gedacht wird!",
            "Könnte man auch einen Wasserspielbereich für den Sommer ergänzen?"
          ]
        },
        {
          title: "Baumpflanzungen in der Innenstadt",
          description: "Pflanzung von 150 klimaresistenten Straßenbäumen in der Innenstadt " \
                       "zur Verbesserung des Stadtklimas und zur Reduktion der sommerlichen Hitze.",
          price: 210_000, feasibility: "feasible", selected: false, winner: false,
          physical_votes: 9,
          comments: [
            "Die Innenstadt braucht dringend mehr Grün, im Sommer staut sich die Hitze extrem.",
            "Bitte heimische Arten wählen, die auch Insekten nützen."
          ]
        },
        {
          title: "Kostenloses WLAN in der Innenstadt",
          description: "Flächendeckendes kostenloses öffentliches WLAN in der gesamten Innenstadt " \
                       "für Anwohner:innen, Besucher:innen und lokale Betriebe.",
          price: 480_000, feasibility: "unfeasible", selected: false, winner: false,
          unfeasibility_explanation: "Laufende Betriebs- und Wartungskosten übersteigen das " \
                                     "verfügbare Budget; Datenschutzanforderungen nicht erfüllbar.",
          physical_votes: 4,
          comments: [
            "Fände ich praktisch, aber der Datenschutz muss wirklich sauber gelöst sein.",
            "Schade, dass es nicht machbar ist – die Begründung ist aber nachvollziehbar."
          ]
        },
        {
          title: "Solarpaneele auf Schuldächern",
          description: "Ausstattung von zehn örtlichen Schulen mit Photovoltaikanlagen zur " \
                       "Eigenstromerzeugung und als Bildungsprojekt für nachhaltige Energie.",
          price: 640_000, feasibility: "undecided", selected: false, winner: false,
          physical_votes: 12,
          comments: [
            "Klimaschutz und Bildung verbinden – perfekt.",
            "Wie sieht es mit der Statik älterer Schuldächer aus?",
            "Bitte die eingesparten Stromkosten transparent dokumentieren."
          ]
        }
      ]

      investments = investment_specs.each_with_index.map do |spec, i|
        author = users[i]
        inv = budget.investments.find_or_initialize_by(title: spec[:title])
        inv.assign_attributes(
          heading: heading,
          group: group,
          budget: budget,
          author: author,
          description: spec[:description],
          price: spec[:price],
          feasibility: spec[:feasibility],
          unfeasibility_explanation: spec[:unfeasibility_explanation].to_s,
          valuation_finished: spec[:feasibility] != "undecided",
          selected: spec[:selected],
          winner: spec[:winner],
          physical_votes: spec[:physical_votes]
        )
        inv.save(validate: false) # seed data: skip terms_of_service acceptance

        spec[:comments].each_with_index do |body, ci|
          commenter = users[(i + ci + 3) % users.size]
          next if Comment.exists?(commentable: inv, user: commenter, body: body)

          Comment.create!(commentable: inv, user: commenter, body: body)
        end

        inv
      end
      log.call "Investments: #{investments.size} (feasible/unfeasible/undecided, selected + 1 winner)"
      log.call "Comments: #{Comment.where(commentable: investments).count}"

      # -----------------------------------------------------------------------
      # Online supports (selecting phase votes)
      # -----------------------------------------------------------------------
      support_count = 0
      investments.each_with_index do |inv, i|
        voters = users.rotate(i).first(10 + i)
        voters.each do |voter|
          next if inv.votes_for.where(voter: voter).exists?

          inv.vote_by(voter: voter, vote: "yes", vote_weight: 1)
          support_count += 1
        end
      end
      log.call "Online supports (votes): #{support_count}"

      # -----------------------------------------------------------------------
      # Ballots (balloting phase) — online + offline, weighted
      # -----------------------------------------------------------------------
      ballot_users = users.first(12)
      selected_investments = investments.select(&:selected?)
      ballot_line_count = 0
      ballot_users.each_with_index do |user, i|
        ballot = Budget::Ballot.find_or_create_by!(budget: budget, user: user) do |b|
          b.physical = i.even? ? false : true
          b.conditional = false
        end

        selected_investments.rotate(i).first(1 + (i % selected_investments.size)).each do |inv|
          line = Budget::Ballot::Line.find_or_initialize_by(ballot: ballot, investment: inv)
          next if line.persisted?

          line.assign_attributes(budget: budget, group: group, heading: heading, line_weight: 1)
          line.save!
          ballot_line_count += 1
        end
      end
      log.call "Ballots: #{ballot_users.size} (mixed online/offline), ballot lines: #{ballot_line_count}"

      # -----------------------------------------------------------------------
      # Compute stats (this is what refresh_stats runs)
      # -----------------------------------------------------------------------
      ProjektPhase::BudgetPhase::StatsService.new(phase).call
      phase.reload

      puts
      puts "== Stats computed =="
      log.call "gender?  #{phase.gender?}"
      log.call "age?     #{phase.age?}"
      log.call "geozone? #{phase.geozone?}"
      log.call "individual_group? #{phase.individual_group?}"
      log.call "participations: #{phase.participations.inspect}"

      puts
      puts "== View it =="
      base = Setting["url"].to_s.chomp("/")
      log.call "#{base}/#{projekt.page.slug}?projekt_phase_id=#{phase.id}&section=key_metrics#projekt-footer"
    end

    puts "Done."
  end
end
