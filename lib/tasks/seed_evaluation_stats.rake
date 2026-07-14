namespace :generate_data do
  desc "Seed the 'Projekt Evaluation' projekt with all four evaluatable phases " \
       "(proposal, voting/poll, budget, comment), each filled with rich test " \
       "data and demographically varied participants (gender/age/geozone/" \
       "individual-group clusters), so the whole /adm evaluation flow can be " \
       "generated and tested end-to-end. Seeds data only — trigger the report " \
       "from the /adm 'Generate evaluation' button. Idempotent / re-runnable. " \
       "Run: bin/rails generate_data:evaluation_stats"
  task evaluation_stats: :environment do
    projekt_name = "Projekt to test evaluation"
    slug = "projekt-to-test-evaluation"
    password = "DemoEval2026!"

    log = ->(msg) { puts "  #{msg}" }

    # Shared content for proposal + budget phases. Proposal reads title/
    # description/comments/votes; budget additionally reads price/feasibility/
    # selected/winner.
    budget_defs = [
      { title: "Neugestaltung des Stadtparks", price: 750_000,
        description: "Umfassende Aufwertung des Stadtparks mit neuen Wegen, Beeten und Ruhezonen.",
        feasibility: "feasible", selected: true, winner: true, votes: 52 },
      { title: "Sanierung des Freibads", price: 1_200_000,
        description: "Grundsanierung der Becken, Umkleiden und der Technik des Freibads.",
        feasibility: "feasible", selected: true, winner: true, votes: 47 },
      { title: "Fahrradbrücke über den Fluss", price: 980_000,
        description: "Eine neue Rad- und Fußgängerbrücke, die zwei Stadtteile direkt verbindet.",
        feasibility: "feasible", selected: true, winner: true, votes: 41 },
      { title: "Barrierefreier Umbau des Bahnhofs", price: 640_000,
        description: "Aufzüge, taktile Leitsysteme und stufenlose Zugänge am Bahnhof.",
        feasibility: "feasible", selected: true, winner: true, votes: 38 },
      { title: "Neue Quartiers-Sporthalle", price: 1_500_000,
        description: "Eine Mehrzweck-Sporthalle für Vereine, Schulen und Nachbarschaft.",
        feasibility: "feasible", selected: true, winner: false, votes: 33 },
      { title: "Ausbau der Kita-Plätze", price: 820_000,
        description: "Erweiterung bestehender Kitas um zusätzliche Gruppenräume.",
        feasibility: "feasible", selected: true, winner: false, votes: 30 },
      { title: "Grüner Schulhof für die Grundschule", price: 280_000,
        description: "Entsiegelung und naturnahe Umgestaltung des Schulhofs.",
        feasibility: "feasible", selected: true, winner: false, votes: 27 },
      { title: "Öffentliche Bücherschränke", price: 45_000,
        description: "Wetterfeste Bücherschränke zum Tauschen an belebten Plätzen.",
        feasibility: "feasible", selected: true, winner: false, votes: 24 },
      { title: "Beleuchtung der Radwege", price: 310_000,
        description: "Sichere, energieeffiziente Beleuchtung entlang der Hauptradwege.",
        feasibility: "feasible", selected: false, winner: false, votes: 19 },
      { title: "Mehrgenerationen-Treffpunkt", price: 520_000,
        description: "Ein offener Treffpunkt für Jung und Alt mit Café und Werkstatt.",
        feasibility: "feasible", selected: false, winner: false, votes: 16 },
      { title: "Wasserspielplatz im Zentrum", price: 190_000,
        description: "Ein Wasserspielplatz als Abkühlung für heiße Sommertage.",
        feasibility: "feasible", selected: false, winner: false, votes: 12 },
      { title: "Urbaner Gemeinschaftsgarten", price: 130_000,
        description: "Gemeinschaftsbeete und Obstbäume auf einer städtischen Brachfläche.",
        feasibility: "feasible", selected: false, winner: false, votes: 10 },
      { title: "Ausbau der E-Ladesäulen", price: 360_000,
        description: "Zusätzliche öffentliche Ladepunkte für Elektrofahrzeuge.",
        feasibility: "undecided", selected: false, winner: false, votes: 14 },
      { title: "Kostenloses Stadt-WLAN", price: 480_000,
        description: "Flächendeckendes kostenloses WLAN in der gesamten Innenstadt.",
        feasibility: "unfeasible", selected: false, winner: false, votes: 8,
        unfeasibility_explanation: "Laufende Betriebs- und Wartungskosten übersteigen das " \
                                   "verfügbare Budget; Datenschutzanforderungen nicht erfüllbar." }
    ]

    budget_comment_pool = [
      "Ein wichtiges Vorhaben – das kommt vielen Menschen zugute.",
      "Bitte bei der Umsetzung auf Nachhaltigkeit und Folgekosten achten.",
      "Endlich! Darauf warten wir im Viertel schon lange.",
      "Gut investiertes Geld, wenn die Qualität stimmt.",
      "Könnte man das barrierefrei und familienfreundlich gestalten?",
      "Ich unterstütze das, wünsche mir aber mehr Transparenz beim Zeitplan."
    ]

    # ONE poll per voting phase, bundling many questions. The set deliberately
    # covers every vote type (unique / multiple / multiple_with_weight /
    # rating_scale) and every chart the evaluation report can render (stacked,
    # measure with an abstain option, donut sentiment, preference, multi, scale)
    # plus verdict-triggering yes/no questions. `weights` biases the answer
    # distribution so charts show meaningful leans instead of a flat split.
    poll_spec = {
      name: "Bürgerbefragung zur Stadtentwicklung",
      questions: [
        { title: "Befürworten Sie die geplante Neugestaltung des Stadtparks?",
          type: "unique", options: ["Ja", "Nein"], weights: [3, 1] },
        { title: "Sollen autofreie Sonntage in der Innenstadt eingeführt werden?",
          type: "unique", options: ["Ja", "Nein", "Keine Angabe"], weights: [5, 3, 2] },
        { title: "Wie bewerten Sie die bisherige Bürgerbeteiligung?",
          type: "unique", options: ["Positiv", "Neutral", "Negativ"], weights: [5, 3, 2] },
        { title: "Wie wichtig ist Ihnen der Ausbau sicherer Radwege?",
          type: "unique",
          options: ["Sehr wichtig", "Eher wichtig", "Weniger wichtig", "Gar nicht wichtig"],
          weights: [6, 4, 2, 1] },
        { title: "Wie zufrieden sind Sie mit dem ÖPNV-Angebot?",
          type: "unique",
          options: ["Sehr zufrieden", "Eher zufrieden", "Eher unzufrieden", "Sehr unzufrieden"],
          weights: [2, 4, 4, 3] },
        { title: "Welche Verkehrsmaßnahmen sollen Vorrang haben?",
          type: "multiple", max_votes: 2,
          options: ["Mehr Busverbindungen", "Tempo 30 in Wohngebieten",
                    "Neue Fahrradstraßen", "Park-and-Ride-Plätze"],
          weights: [5, 3, 4, 2] },
        { title: "Welche Klimaschutzmaßnahmen befürworten Sie?",
          type: "multiple", max_votes: 3,
          options: ["Baumpflanzungen", "Solardächer", "Flächenentsiegelung",
                    "Regenwassernutzung", "Fassadenbegrünung"],
          weights: [6, 4, 5, 3, 2] },
        { title: "Verteilen Sie Ihre Stimmen auf die wichtigsten Vorhaben.",
          type: "multiple_with_weight", max_votes: 5, max_votes_per_answer: 3,
          options: ["Schulsanierung", "Radwegenetz", "Stadtgrün", "Digitalisierung"],
          weights: [5, 4, 3, 2] },
        { title: "Wie gewichten Sie die Bereiche des Klimabudgets?",
          type: "multiple_with_weight", max_votes: 6, max_votes_per_answer: 4,
          options: ["Energie", "Mobilität", "Gebäude", "Grünflächen", "Aufklärung"],
          weights: [5, 5, 3, 4, 2] },
        { title: "Wie sicher fühlen Sie sich im Straßenverkehr?",
          type: "rating_scale", options: ["1", "2", "3", "4", "5"],
          min_rating_scale_label: "Sehr unsicher", max_rating_scale_label: "Sehr sicher",
          weights: [2, 4, 6, 4, 2] },
        { title: "Wie beurteilen Sie die Sauberkeit öffentlicher Plätze?",
          type: "rating_scale", options: ["1", "2", "3", "4", "5"],
          min_rating_scale_label: "Sehr schlecht", max_rating_scale_label: "Sehr gut",
          weights: [1, 3, 5, 6, 3] },
        { title: "Sind Sie dafür, mehr Straßenbäume in der Innenstadt zu pflanzen?",
          type: "unique", options: ["Dafür", "Dagegen"], weights: [3, 2] }
      ]
    }

    # A bundled question: one DB-level Poll::Question with bundle_question: true
    # grouping several nested (parent_question_id-linked) sub-questions, exactly
    # like real bundles created via the poll editor. Exercises the evaluation
    # report's bundle-grouping path (nested questions rendered under their
    # parent instead of as flat, unrelated cards).
    bundle_spec = {
      title: "Fragenbündel: Naherholung im Stadtpark",
      questions: [
        { title: "Wie oft nutzen Sie den Stadtpark aktuell?",
          type: "unique", options: ["Täglich", "Wöchentlich", "Selten", "Nie"],
          weights: [3, 5, 4, 2] },
        { title: "Welche Angebote im Park nutzen Sie am meisten?",
          type: "multiple", max_votes: 2,
          options: ["Spielplatz", "Liegewiese", "Sportgeräte", "Gastronomie"],
          weights: [5, 6, 3, 2] },
        { title: "Wie bewerten Sie die Aufenthaltsqualität aktuell?",
          type: "rating_scale", options: ["1", "2", "3", "4", "5"],
          min_rating_scale_label: "Sehr schlecht", max_rating_scale_label: "Sehr gut",
          weights: [2, 3, 6, 5, 2] }
      ]
    }

    comment_phase_bodies = [
      "Die Idee mit den Fahrradstraßen finde ich hervorragend – bitte zügig umsetzen!",
      "Mehr Grünflächen würden dem Stadtklima spürbar helfen.",
      "Mir fehlen konkrete Angaben zur Finanzierung der einzelnen Projekte.",
      "Die Beteiligung ist gut organisiert, vielen Dank dafür.",
      "Bitte auch die Randbezirke stärker einbeziehen, nicht nur die Innenstadt.",
      "Der Zeitplan wirkt sehr ambitioniert – ist das realistisch?",
      "Barrierefreiheit sollte bei allen Maßnahmen von Anfang an mitgedacht werden.",
      "Ich hätte mir mehr Informationsveranstaltungen vor Ort gewünscht.",
      "Solaranlagen auf öffentlichen Gebäuden – das sollte unbedingt weiterverfolgt werden.",
      "Insgesamt ein guter Prozess, aber die Rückmeldungen an die Bürger:innen könnten schneller sein."
    ]

    # Proposal-phase content (kept separate from the budget investments above so
    # the proposal phase can hold many more items).
    proposal_defs = [
      { title: "Sichere Fahrradstraße entlang des Flusses",
        description: "Eine durchgehende, sichere Fahrradstraße vom Zentrum bis zum Stadtrand." },
      { title: "Neue Spielplätze im Stadtpark",
        description: "Sanierung bestehender und Bau neuer, barrierefreier Spielbereiche." },
      { title: "Mehr Straßenbäume in der Innenstadt",
        description: "Pflanzung klimaresistenter Straßenbäume gegen die sommerliche Hitze." },
      { title: "Ausbau des Nachtbusnetzes",
        description: "Dichtere Taktung und neue Linien für sichere Heimwege am Wochenende." },
      { title: "Öffentliche Trinkwasserbrunnen",
        description: "Kostenlose Trinkwasserbrunnen an zentralen Plätzen und in Parks." },
      { title: "Sanierung der Schulturnhallen",
        description: "Grundsanierung maroder Turnhallen an den städtischen Schulen." },
      { title: "Erweiterung der Stadtbibliothek",
        description: "Längere Öffnungszeiten und mehr Lern- und Arbeitsplätze." },
      { title: "Lastenräder zum kostenlosen Ausleihen",
        description: "Ein Verleihsystem für Lastenräder in allen Stadtteilen." },
      { title: "Begrünung von Bushaltestellen",
        description: "Dachbegrünung der Wartehäuschen für besseres Kleinklima." },
      { title: "Barrierefreie Umgestaltung des Marktplatzes",
        description: "Ebene Wege, Leitsysteme und Sitzgelegenheiten für alle." },
      { title: "Jugendzentrum im Stadtteil Süd",
        description: "Ein offener Treffpunkt mit Angeboten für Jugendliche." },
      { title: "Mehr Sitzbänke und Schattenplätze",
        description: "Zusätzliche Bänke und Beschattung entlang der Hauptwege." },
      { title: "Ausbau der Ladeinfrastruktur für E-Autos",
        description: "Mehr öffentliche Ladepunkte in Wohnquartieren." },
      { title: "Urban-Gardening-Flächen für Anwohner:innen",
        description: "Gemeinschaftsbeete auf brachliegenden städtischen Flächen." },
      { title: "Verkehrsberuhigung vor Kindergärten",
        description: "Tempo-30-Zonen und sichere Querungen im Umfeld von Kitas." },
      { title: "Digitale Bürgersprechstunde einführen",
        description: "Regelmäßige Online-Sprechstunden mit der Verwaltung." },
      { title: "Renaturierung des Stadtbachs",
        description: "Öffnung und naturnahe Gestaltung des verrohrten Stadtbachs." },
      { title: "Mehr öffentliche Toiletten in der Innenstadt",
        description: "Ausbau barrierefreier, gepflegter öffentlicher Toiletten." },
      { title: "Kulturprogramm im Stadtpark im Sommer",
        description: "Kostenlose Konzerte und Lesungen an Sommerwochenenden." },
      { title: "Photovoltaik auf städtischen Dächern",
        description: "Solaranlagen auf Verwaltungsgebäuden und Schulen." },
      { title: "Reparaturcafé in jedem Stadtteil",
        description: "Offene Werkstätten zum gemeinsamen Reparieren statt Wegwerfen." },
      { title: "Sichere Schulwege mit Zebrastreifen",
        description: "Neue Fußgängerüberwege und Beleuchtung auf Schulwegen." }
    ]

    proposal_comment_pool = [
      "Eine sehr sinnvolle Idee, die ich voll unterstütze.",
      "Wichtig ist, dass die Umsetzung gut geplant und finanziert wird.",
      "Bitte auch die Anwohner:innen frühzeitig einbeziehen.",
      "Das würde die Lebensqualität im Viertel deutlich verbessern.",
      "Guter Vorschlag – bitte auf Barrierefreiheit achten.",
      "Ich hätte gern mehr Details zu den Kosten und dem Zeitplan."
    ]

    ActiveRecord::Base.transaction do
      puts "== Projekt Evaluation seed =="

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
          color: "#1E40AF",
          icon: "insights"
        )
        projekt.projekt_settings.find_by(key: "projekt_feature.main.activate")&.update!(value: "active")
        projekt.page.update!(status: "published", title: projekt_name,
                             content: "Beteiligungsprojekt – Testdaten für die Auswertung", locale: "de")
        log.call "Created projekt ##{projekt.id} (slug=#{projekt.page.slug})"
      end

      # -----------------------------------------------------------------------
      # Geozones = RegisteredAddress::District (geozone charts are district-driven)
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
      # Individual groups (soft clusters) + values (budget-phase demographics)
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
      # Weighted demographic pools produce realistic distributions so every chart
      # (gender/age/geozone/clusters) — including the Conclusion segment — has
      # meaningful counts, not one participant per bucket.
      age_weights = {
        19 => 4, 24 => 7, 29 => 9, 34 => 11, 39 => 11, 44 => 10,
        49 => 9, 54 => 8, 59 => 7, 64 => 6, 69 => 4, 74 => 3, 79 => 2, 86 => 1
      }
      ages = age_weights.flat_map { |age, count| Array.new(count, age) }
      gender_cycle = %w[female male female male other_gen female male male female male]

      people = ages.each_with_index.map do |age, i|
        [
          gender_cycle[i % gender_cycle.size],
          age,
          i % districts.size,
          [0, 1, 2, nil][i % 4],
          [2, nil, 0, 1][i % 4]
        ]
      end

      users = people.each_with_index.map do |(gender, age, gz, mi, ii), idx|
        email = "eval_demo_#{idx + 1}@consul.dev"
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
          username: "Eval Demo Bürger:in #{idx + 1}",
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

      # =======================================================================
      # PROPOSAL PHASE
      # =======================================================================
      proposal_phase = projekt.projekt_phases.find_by(type: "ProjektPhase::ProposalPhase")
      unless proposal_phase
        proposal_phase = ProjektPhase::ProposalPhase.create!(
          projekt: projekt, active: true, frontend_visibility: true,
          start_date: 6.months.ago, end_date: 5.months.ago, phase_tab_name: "Vorschläge"
        )
      end
      proposal_phase.update!(active: true, frontend_visibility: true)
      proposal_phase.settings.find_or_initialize_by(key: "feature.general.public_kpi_stats").update!(value: "active")
      proposal_phase.settings.find_or_initialize_by(key: "feature.resource.show_comments").update!(value: "active")

      proposals = proposal_defs.each_with_index.map do |pdef, i|
        author = users[i % users.size]
        proposal = proposal_phase.proposals.find_or_initialize_by(title: pdef[:title])
        proposal.assign_attributes(
          projekt_phase: proposal_phase, author: author, description: pdef[:description],
          responsible_name: "Eval Demo Bürger:in #{(i % users.size) + 1}",
          officing_bulk_votes: (3 + (i * 7) % 45),
          draft: false, published_at: Time.current, admin_accepted: true
        )
        proposal.save(validate: false)

        2.times do |ci|
          body = proposal_comment_pool[(i + ci) % proposal_comment_pool.size]
          commenter = users[(i + ci + 3) % users.size]
          next if Comment.exists?(commentable: proposal, user: commenter, body: body)

          Comment.create!(commentable: proposal, user: commenter, body: body)
        end

        proposal
      end

      proposals.each_with_index do |proposal, i|
        voters = users.rotate(i).first(10 + i)
        voters.each do |voter|
          next if proposal.votes_for.where(voter: voter).exists?

          proposal.vote_by(voter: voter, vote: "yes")
        end
      end
      ProjektPhase::ProposalPhase::StatsService.new(proposal_phase).call
      log.call "Proposal phase ##{proposal_phase.id}: #{proposals.size} proposals, " \
               "#{Comment.where(commentable: proposals).count} comments"

      # =======================================================================
      # VOTING PHASE (one poll bundling many questions, answers, votes, voters)
      # =======================================================================
      voting_phase = projekt.projekt_phases.find_by(type: "ProjektPhase::VotingPhase")
      unless voting_phase
        voting_phase = ProjektPhase::VotingPhase.create!(
          projekt: projekt, active: true, frontend_visibility: true,
          start_date: 4.months.ago, end_date: 3.months.ago, phase_tab_name: "Abstimmung"
        )
      end
      voting_phase.update!(active: true, frontend_visibility: true)
      voting_phase.settings.find_or_initialize_by(key: "feature.general.public_kpi_stats").update!(value: "active")

      poll = voting_phase.polls.order(:id).first
      poll ||= voting_phase.polls.create!(name: poll_spec[:name], slug: "#{slug}-poll")
      poll.update!(
        name: poll_spec[:name], starts_at: 4.months.ago, ends_at: 3.months.ago,
        results_enabled: true, stats_enabled: true, published: true
      )

      # Deterministic weighted pick: expands weights [3, 1] into indices
      # [0, 0, 0, 1], so voter i maps to bag[i % bag.size] and the target answer
      # distribution is reproduced without randomness.
      weighted_bag = lambda do |weights, size|
        bag = weights.each_with_index.flat_map { |weight, index| Array.new(weight, index) }
        bag.empty? ? (0...size).to_a : bag
      end

      # Per-voter weight allocations for multiple_with_weight, keyed by the total
      # vote budget. Each inner array sums to the budget and each element stays
      # within the per-answer cap, so the model's weight validation passes.
      weight_allocations = {
        5 => [[3, 2], [2, 2, 1], [3, 1, 1], [2, 1, 1, 1]],
        6 => [[4, 2], [3, 3], [4, 1, 1], [3, 2, 1], [2, 2, 1, 1]]
      }

      find_or_create_question = lambda do |qspec, parent_question: nil|
        question = poll.questions.find_by(title: qspec[:title])

        return question if question

        question = Poll::Question.new(
          poll: poll, author: users.first, title: qspec[:title], parent_question_id: parent_question&.id
        )
        question.votation_type = VotationType.new(
          vote_type: qspec[:type],
          max_votes: qspec[:max_votes],
          max_votes_per_answer: qspec[:max_votes_per_answer],
          min_rating_scale_label: qspec[:min_rating_scale_label],
          max_rating_scale_label: qspec[:max_rating_scale_label]
        )
        question.save!

        qspec[:options].each_with_index do |option_title, oi|
          Poll::Question::Answer.create!(question: question, title: option_title, given_order: oi + 1)
        end

        question
      end

      total_answers = 0
      cast_votes = lambda do |question, qspec, qi|
        options = qspec[:options]
        bag = weighted_bag.call(qspec[:weights] || [], options.size)
        voters = users.rotate(qi * 3).first(40)

        voters.each_with_index do |voter, vi|
          next if Poll::Answer.where(question_id: question.id, author_id: voter.id).exists?

          case qspec[:type]
          when "unique", "rating_scale"
            title = options[bag[vi % bag.size]]
            Poll::Answer.create!(question_id: question.id, author: voter, answer: title, answer_weight: 1)
            total_answers += 1
          when "multiple"
            chosen = []
            offset = 0

            while chosen.size < qspec[:max_votes] && offset < bag.size + options.size
              title = options[bag[(vi + offset) % bag.size]]
              chosen << title unless chosen.include?(title)
              offset += 1
            end

            chosen.each do |title|
              Poll::Answer.create!(question_id: question.id, author: voter, answer: title, answer_weight: 1)
              total_answers += 1
            end
          when "multiple_with_weight"
            patterns = weight_allocations[qspec[:max_votes]]
            allocation = patterns[vi % patterns.size]
            start_index = bag[vi % bag.size]

            allocation.each_with_index do |weight, slot|
              title = options[(start_index + slot) % options.size]
              Poll::Answer.create!(
                question_id: question.id, author: voter, answer: title, answer_weight: weight
              )
              total_answers += 1
            end
          end
        end
      end

      poll_spec[:questions].each_with_index do |qspec, qi|
        question = find_or_create_question.call(qspec)
        cast_votes.call(question, qspec, qi)
      end

      bundle_question = poll.questions.find_by(title: bundle_spec[:title])
      unless bundle_question
        bundle_question = Poll::Question.create!(
          poll: poll, author: users.first, title: bundle_spec[:title], bundle_question: true,
          votation_type: VotationType.new(vote_type: nil)
        )
      end

      bundle_spec[:questions].each_with_index do |qspec, qi|
        question = find_or_create_question.call(qspec, parent_question: bundle_question)
        cast_votes.call(question, qspec, poll_spec[:questions].size + qi)
      end

      poll.questions.flat_map(&:answers).map(&:author).uniq.each do |voter|
        Poll::Voter.find_or_create_by!(user: voter, poll: poll, origin: "web")
      end
      log.call "Voting phase ##{voting_phase.id}: 1 poll, " \
               "#{poll.questions.count} questions, #{total_answers} answers"

      # =======================================================================
      # BUDGET PHASE (budget, investments, comments, supports, ballots)
      # =======================================================================
      budget_phase = projekt.projekt_phases.find_by(type: "ProjektPhase::BudgetPhase")
      unless budget_phase
        budget_phase = ProjektPhase::BudgetPhase.create!(
          projekt: projekt, active: true, frontend_visibility: true,
          start_date: 2.months.ago, end_date: 1.month.ago, phase_tab_name: "Bürgerhaushalt"
        )
      end
      budget_phase.update!(active: true, frontend_visibility: true)
      budget_phase.settings.find_or_initialize_by(key: "feature.general.public_kpi_stats").update!(value: "active")
      budget_phase.settings.find_or_initialize_by(key: "feature.resource.show_comments").update!(value: "active")

      budget = budget_phase.reload.budget
      budget.update!(phase: "finished", results_enabled: true, stats_enabled: true, published: true)
      heading = budget.heading
      group = budget.group
      heading.update!(price: 5_000_000, population: 120_000)

      today = Date.current
      budget.phases.order(:id).each_with_index do |ph, i|
        ph.update_columns(enabled: true,
                          starts_at: today - (9 - i).months,
                          ends_at: today - (8 - i).months)
      end
      budget.phases.finished.update_columns(starts_at: today - 3.days, ends_at: today + 3.days)
      budget.reload

      investments = budget_defs.each_with_index.map do |spec, i|
        author = users[i % users.size]
        inv = budget.investments.find_or_initialize_by(title: spec[:title])
        inv.assign_attributes(
          heading: heading, group: group, budget: budget, author: author,
          description: spec[:description], price: spec[:price], feasibility: spec[:feasibility],
          unfeasibility_explanation: spec[:unfeasibility_explanation].to_s,
          valuation_finished: spec[:feasibility] != "undecided",
          selected: spec[:selected], winner: spec[:winner], physical_votes: spec[:votes]
        )
        inv.save(validate: false)

        2.times do |ci|
          body = budget_comment_pool[(i + ci) % budget_comment_pool.size]
          commenter = users[(i + ci + 3) % users.size]
          next if Comment.exists?(commentable: inv, user: commenter, body: body)

          Comment.create!(commentable: inv, user: commenter, body: body)
        end

        inv
      end

      investments.each_with_index do |inv, i|
        voters = users.rotate(i).first(10 + i)
        voters.each do |voter|
          next if inv.votes_for.where(voter: voter).exists?

          inv.vote_by(voter: voter, vote: "yes", vote_weight: 1)
        end
      end

      # Every participant casts a ballot that includes winning investments, so
      # the "Conclusion" (finished) segment gets a demographically rich cohort.
      winner_investments = investments.select(&:winner?)
      selected_investments = investments.select(&:selected?)
      users.each_with_index do |user, i|
        ballot = Budget::Ballot.find_or_create_by!(budget: budget, user: user) do |b|
          b.physical = i.odd?
          b.conditional = false
        end

        targets = (winner_investments.rotate(i).first(2) + selected_investments.rotate(i).first(1)).uniq
        targets.each do |inv|
          line = Budget::Ballot::Line.find_or_initialize_by(ballot: ballot, investment: inv)
          next if line.persisted?

          line.assign_attributes(budget: budget, group: group, heading: heading, line_weight: 1)
          line.save!
        end
      end

      ProjektPhase::BudgetPhase::StatsService.new(budget_phase).call
      log.call "Budget phase ##{budget_phase.id}: #{investments.size} investments, " \
               "#{Comment.where(commentable: investments).count} comments, " \
               "#{Budget::Ballot.where(budget: budget).count} ballots"

      # =======================================================================
      # COMMENT PHASE (discussion comments on the phase)
      # =======================================================================
      comment_phase = projekt.projekt_phases.find_by(type: "ProjektPhase::CommentPhase")
      unless comment_phase
        comment_phase = ProjektPhase::CommentPhase.create!(
          projekt: projekt, active: true, frontend_visibility: true,
          start_date: 5.months.ago, end_date: 1.month.ago, phase_tab_name: "Diskussion"
        )
      end
      comment_phase.update!(active: true, frontend_visibility: true)

      comment_phase_bodies.each_with_index do |body, i|
        user = users[i % users.size]
        next if Comment.exists?(commentable: comment_phase, user: user, body: body)

        Comment.create!(commentable: comment_phase, user: user, body: body)
      end
      log.call "Comment phase ##{comment_phase.id}: #{Comment.where(commentable: comment_phase).count} comments"

      puts
      puts "== Seeded phases =="
      projekt.projekt_phases.sorted.each do |phase|
        log.call "##{phase.id} #{phase.type}"
      end

      puts
      puts "== Next step =="
      base = Setting["url"].to_s.chomp("/")
      log.call "Frontend:   #{base}/#{projekt.page.slug}"
      log.call "Generate the evaluation report in /adm, then open it:"
      log.call "#{base}/adm/projekts/#{projekt.id}/evaluation"
      log.call "Demo users password: #{password}"
    end

    puts "Done."
  end
end
