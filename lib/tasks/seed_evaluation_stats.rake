namespace :demo do
  desc "Seed the 'Projekt Evaluation' projekt with all four evaluatable phases " \
       "(proposal, voting/poll, budget, comment), each filled with rich test " \
       "data and demographically varied participants (gender/age/geozone/" \
       "individual-group clusters), so the whole /adm evaluation flow can be " \
       "generated and tested end-to-end. Seeds data only — trigger the report " \
       "from the /adm 'Generate evaluation' button. Idempotent / re-runnable. " \
       "Run: bin/rails demo:evaluation_stats"
  task evaluation_stats: :environment do
    projekt_name = "Projekt Evaluation"
    slug = "projekt-evaluation"
    password = "DemoEval2026!"

    log = ->(msg) { puts "  #{msg}" }

    # Shared content for proposal + budget phases. Proposal reads title/
    # description/comments/votes; budget additionally reads price/feasibility/
    # selected/winner.
    specs = [
      {
        title: "Fahrradstraße entlang des Flusses",
        description: "Eine durchgehende, sichere Fahrradstraße entlang des Flusses vom " \
                     "Zentrum bis zum Stadtrand. Sie verbindet Wohnviertel mit der " \
                     "Innenstadt und entlastet die Hauptverkehrsachsen.",
        price: 850_000, feasibility: "feasible", selected: true, winner: true, votes: 40,
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
        price: 320_000, feasibility: "feasible", selected: true, winner: false, votes: 18,
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
        price: 210_000, feasibility: "feasible", selected: false, winner: false, votes: 9,
        comments: [
          "Die Innenstadt braucht dringend mehr Grün, im Sommer staut sich die Hitze extrem.",
          "Bitte heimische Arten wählen, die auch Insekten nützen."
        ]
      },
      {
        title: "Kostenloses WLAN in der Innenstadt",
        description: "Flächendeckendes kostenloses öffentliches WLAN in der gesamten Innenstadt " \
                     "für Anwohner:innen, Besucher:innen und lokale Betriebe.",
        price: 480_000, feasibility: "unfeasible", selected: false, winner: false, votes: 4,
        unfeasibility_explanation: "Laufende Betriebs- und Wartungskosten übersteigen das " \
                                   "verfügbare Budget; Datenschutzanforderungen nicht erfüllbar.",
        comments: [
          "Fände ich praktisch, aber der Datenschutz muss wirklich sauber gelöst sein.",
          "Schade, dass es nicht machbar ist – die Begründung ist aber nachvollziehbar."
        ]
      },
      {
        title: "Solarpaneele auf Schuldächern",
        description: "Ausstattung von zehn örtlichen Schulen mit Photovoltaikanlagen zur " \
                     "Eigenstromerzeugung und als Bildungsprojekt für nachhaltige Energie.",
        price: 640_000, feasibility: "undecided", selected: false, winner: false, votes: 12,
        comments: [
          "Klimaschutz und Bildung verbinden – perfekt.",
          "Wie sieht es mit der Statik älterer Schuldächer aus?",
          "Bitte die eingesparten Stromkosten transparent dokumentieren."
        ]
      }
    ]

    poll_specs = [
      {
        name: "Verkehr & Mobilität",
        questions: [
          { title: "Wie wichtig ist Ihnen der Ausbau sicherer Radwege?", type: "unique",
            options: ["Sehr wichtig", "Eher wichtig", "Weniger wichtig", "Gar nicht wichtig"] },
          { title: "Welche Verkehrsmaßnahmen sollen Vorrang haben?", type: "multiple", max_votes: 2,
            options: ["Mehr Busverbindungen", "Tempo 30 in Wohngebieten", "Neue Fahrradstraßen", "Park-and-Ride-Plätze"] },
          { title: "Wie zufrieden sind Sie mit dem ÖPNV-Angebot?", type: "unique",
            options: ["Sehr zufrieden", "Eher zufrieden", "Eher unzufrieden", "Sehr unzufrieden"] }
        ]
      },
      {
        name: "Stadtgrün & Klima",
        questions: [
          { title: "Wie wichtig ist Ihnen mehr Stadtgrün in der Innenstadt?", type: "unique",
            options: ["Sehr wichtig", "Wichtig", "Neutral", "Unwichtig"] },
          { title: "Welche Klimaschutzmaßnahmen befürworten Sie?", type: "multiple", max_votes: 2,
            options: ["Baumpflanzungen", "Solardächer", "Flächenentsiegelung", "Regenwassernutzung"] }
        ]
      }
    ]

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
      people = [
        ["female",    18, 0, 0, 0], ["male",      22, 1, nil, 1], ["female",    24, 2, 1, 0],
        ["male",      27, 3, 2, 2], ["other_gen", 29, 0, 0, 1], ["female",    31, 1, nil, 0],
        ["male",      34, 2, 1, 1], ["female",    37, 3, 0, 2], ["male",      41, 0, 2, nil],
        ["female",    44, 1, 1, 0], ["other_gen", 48, 2, nil, 1], ["male",      52, 3, 0, 2],
        ["female",    57, 0, 1, 0], ["male",      61, 1, 2, 1], ["female",    66, 2, 0, nil],
        ["male",      71, 3, 1, 2], ["other_gen", 76, 0, nil, 0], ["female",    83, 1, 0, 1]
      ]

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
      # VOTING PHASE (polls, questions, answer options, votes, voters)
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

      polls = voting_phase.polls.order(:id).to_a
      while polls.size < poll_specs.size
        index = polls.size + 1
        polls << voting_phase.polls.create!(
          name: "#{projekt_name} #{index}", slug: "#{slug}-poll-#{index}"
        )
      end

      total_answers = 0
      polls.each_with_index do |poll, pi|
        spec = poll_specs[pi]
        poll.update!(
          name: spec[:name], starts_at: 4.months.ago, ends_at: 3.months.ago,
          results_enabled: true, stats_enabled: true, published: true
        )

        if poll.questions.count.zero?
          spec[:questions].each do |qspec|
            question = Poll::Question.new(poll: poll, author: users.first, title: qspec[:title])
            question.votation_type = VotationType.new(vote_type: qspec[:type], max_votes: qspec[:max_votes])
            question.save!

            qspec[:options].each_with_index do |option_title, oi|
              Poll::Question::Answer.create!(question: question, title: option_title, given_order: oi + 1)
            end
          end
        end

        poll.questions.includes(:votation_type, :question_answers).each_with_index do |question, qi|
          option_titles = question.question_answers.sort_by(&:given_order).map(&:title)
          next if option_titles.empty?

          vote_limit = question.unique? ? 1 : (question.votation_type&.max_votes || 2)
          voters = users.rotate(qi).first(12)

          voters.each_with_index do |voter, vi|
            next if Poll::Answer.where(question_id: question.id, author_id: voter.id).exists?

            chosen = [option_titles[vi % option_titles.size]]
            chosen << option_titles[(vi + 1) % option_titles.size] if vote_limit > 1
            chosen.uniq.first(vote_limit).each do |title|
              Poll::Answer.create!(question_id: question.id, author: voter, answer: title, answer_weight: 1)
              total_answers += 1
            end
          end
        end

        poll.questions.flat_map(&:answers).map(&:author).uniq.each do |voter|
          Poll::Voter.find_or_create_by!(user: voter, poll: poll, origin: "web")
        end
      end
      log.call "Voting phase ##{voting_phase.id}: #{polls.size} polls, " \
               "#{polls.sum { |p| p.questions.count }} questions, #{total_answers} answers"

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

      investments = specs.each_with_index.map do |spec, i|
        author = users[i]
        inv = budget.investments.find_or_initialize_by(title: spec[:title])
        inv.assign_attributes(
          heading: heading, group: group, budget: budget, author: author,
          description: spec[:description], price: spec[:price], feasibility: spec[:feasibility],
          unfeasibility_explanation: spec[:unfeasibility_explanation].to_s,
          valuation_finished: spec[:feasibility] != "undecided",
          selected: spec[:selected], winner: spec[:winner], physical_votes: spec[:votes]
        )
        inv.save(validate: false)

        spec[:comments].each_with_index do |body, ci|
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

      ballot_users = users.first(12)
      selected_investments = investments.select(&:selected?)
      ballot_users.each_with_index do |user, i|
        ballot = Budget::Ballot.find_or_create_by!(budget: budget, user: user) do |b|
          b.physical = i.odd?
          b.conditional = false
        end

        selected_investments.rotate(i).first(1 + (i % selected_investments.size)).each do |inv|
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
