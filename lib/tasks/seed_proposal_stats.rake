namespace :demo do
  desc "Seed the 'Munich budget stats' projekt with a proposal phase, 5 " \
       "proposals (full data), comments, online supports, offline bulk votes " \
       "and demographically rich participants (gender/age/geozone clusters) " \
       "to exercise the proposal-phase Kennzahlen (key_metrics) stats. " \
       "Idempotent / re-runnable. Run: bin/rails demo:proposal_stats"
  task proposal_stats: :environment do
    projekt_name = "Munich budget stats"
    slug = "munich-budget-stats"
    password = "DemoProposal2026!"

    log = ->(msg) { puts "  #{msg}" }

    ActiveRecord::Base.transaction do
      puts "== Proposal stats demo seed =="

      # -----------------------------------------------------------------------
      # Projekt + page (reuse the existing munich-budget-stats projekt)
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
          icon: "lightbulb_outline"
        )
        projekt.projekt_settings.find_by(key: "projekt_feature.main.activate")&.update!(value: "active")
        projekt.page.update!(status: "published", title: projekt_name,
                             content: "Bürgerbeteiligung – Testdaten", locale: "de")
        log.call "Created projekt ##{projekt.id} (slug=#{projekt.page.slug})"
      end

      # -----------------------------------------------------------------------
      # Proposal phase, enable public KPI + comments
      # -----------------------------------------------------------------------
      phase = projekt.projekt_phases.find_by(type: "ProjektPhase::ProposalPhase")
      unless phase
        phase = ProjektPhase::ProposalPhase.create!(
          projekt: projekt,
          active: true,
          frontend_visibility: true,
          start_date: 1.month.ago,
          end_date: 2.months.from_now,
          phase_tab_name: "Vorschläge"
        )
        log.call "Created proposal phase ##{phase.id}"
      end
      phase.update!(active: true, frontend_visibility: true)
      phase.settings.find_or_initialize_by(key: "feature.general.public_kpi_stats").update!(value: "active")
      phase.settings.find_or_initialize_by(key: "feature.resource.show_comments").update!(value: "active")
      phase.reload
      log.call "Proposal phase ##{phase.id} on projekt ##{projekt.id}"

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
      # Participants with full demographic data
      # [gender, age, geozone_index]. The proposal phase stats service only
      # reads gender/age/geozone (individual_group? is hardcoded false), so no
      # individual-group clusters are seeded here.
      # -----------------------------------------------------------------------
      people = [
        ["female",    18, 0], ["male",      22, 1], ["female",    24, 2],
        ["male",      27, 3], ["other_gen", 29, 0], ["female",    31, 1],
        ["male",      34, 2], ["female",    37, 3], ["male",      41, 0],
        ["female",    44, 1], ["other_gen", 48, 2], ["male",      52, 3],
        ["female",    57, 0], ["male",      61, 1], ["female",    66, 2],
        ["male",      71, 3], ["other_gen", 76, 0], ["female",    83, 1]
      ]

      users = people.each_with_index.map do |(gender, age, gz), idx|
        email = "proposal_stats_demo_#{idx + 1}@consul.dev"
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
          username: "Demo Vorschlag Bürger:in #{idx + 1}",
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

        user
      end
      log.call "Participants: #{users.size} (M/F/D + varied ages, 4 geozones)"

      # -----------------------------------------------------------------------
      # Proposals (full data) + feedback comments + offline bulk votes
      # -----------------------------------------------------------------------
      proposal_specs = [
        {
          title: "Fahrradstraße entlang des Flusses",
          description: "Eine durchgehende, sichere Fahrradstraße entlang des Flusses vom " \
                       "Zentrum bis zum Stadtrand. Sie verbindet Wohnviertel mit der " \
                       "Innenstadt und entlastet die Hauptverkehrsachsen.",
          offline_votes: 40,
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
          offline_votes: 18,
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
          offline_votes: 9,
          comments: [
            "Die Innenstadt braucht dringend mehr Grün, im Sommer staut sich die Hitze extrem.",
            "Bitte heimische Arten wählen, die auch Insekten nützen."
          ]
        },
        {
          title: "Kostenloses WLAN in der Innenstadt",
          description: "Flächendeckendes kostenloses öffentliches WLAN in der gesamten Innenstadt " \
                       "für Anwohner:innen, Besucher:innen und lokale Betriebe.",
          offline_votes: 4,
          comments: [
            "Fände ich praktisch, aber der Datenschutz muss wirklich sauber gelöst sein.",
            "Ein flächendeckendes Netz wäre ein echter Standortvorteil für die lokalen Geschäfte."
          ]
        },
        {
          title: "Solarpaneele auf Schuldächern",
          description: "Ausstattung von zehn örtlichen Schulen mit Photovoltaikanlagen zur " \
                       "Eigenstromerzeugung und als Bildungsprojekt für nachhaltige Energie.",
          offline_votes: 12,
          comments: [
            "Klimaschutz und Bildung verbinden – perfekt.",
            "Wie sieht es mit der Statik älterer Schuldächer aus?",
            "Bitte die eingesparten Stromkosten transparent dokumentieren."
          ]
        }
      ]

      proposals = proposal_specs.each_with_index.map do |spec, i|
        author = users[i]
        proposal = phase.proposals.find_or_initialize_by(title: spec[:title])
        proposal.assign_attributes(
          projekt_phase: phase,
          author: author,
          description: spec[:description],
          responsible_name: "Demo Bürger:in #{i + 1}",
          officing_bulk_votes: spec[:offline_votes],
          draft: false,
          published_at: Time.current,
          admin_accepted: true
        )
        proposal.save(validate: false) # seed data: skip terms-of-service acceptance

        spec[:comments].each_with_index do |body, ci|
          commenter = users[(i + ci + 3) % users.size]
          next if Comment.exists?(commentable: proposal, user: commenter, body: body)

          Comment.create!(commentable: proposal, user: commenter, body: body)
        end

        proposal
      end
      log.call "Proposals: #{proposals.size}"
      log.call "Comments: #{Comment.where(commentable: proposals).count}"

      # -----------------------------------------------------------------------
      # Online supports (votes)
      # -----------------------------------------------------------------------
      support_count = 0
      proposals.each_with_index do |proposal, i|
        voters = users.rotate(i).first(10 + i)
        voters.each do |voter|
          next if proposal.votes_for.where(voter: voter).exists?

          proposal.vote_by(voter: voter, vote: "yes")
          support_count += 1
        end
      end
      log.call "Online supports (votes): #{support_count}"
      log.call "Offline bulk votes: #{proposals.sum(&:officing_bulk_votes)}"

      # -----------------------------------------------------------------------
      # Compute stats (this is what refresh_stats runs)
      # -----------------------------------------------------------------------
      ProjektPhase::ProposalPhase::StatsService.new(phase).call
      phase.reload

      puts
      puts "== Stats computed =="
      log.call "gender?  #{phase.gender?}"
      log.call "age?     #{phase.age?}"
      log.call "geozone? #{phase.geozone?}"
      log.call "participations: #{phase.participations.inspect}"
      log.call "visible_proposals_count: #{phase.visible_proposals_count}"
      log.call "unique_supporters_count: #{phase.unique_supporters_count}"
      log.call "total_votes_count: #{phase.total_votes_count}"

      puts
      puts "== View it =="
      base = Setting["url"].to_s.chomp("/")
      log.call "#{base}/#{projekt.page.slug}?projekt_phase_id=#{phase.id}&section=key_metrics#projekt-footer"
    end

    puts "Done."
  end
end
