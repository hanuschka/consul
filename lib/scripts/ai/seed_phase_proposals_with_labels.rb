require "json"

class Ai::SeedPhaseProposalsWithLabels
  LABELS = [
    { name: "Mobilität",       color: "#3B82F6", icon: "bicycle" },
    { name: "Grünflächen",     color: "#10B981", icon: "tree" },
    { name: "Kultur",          color: "#A855F7", icon: "theater-masks" },
    { name: "Klima",           color: "#0EA5E9", icon: "cloud-sun" },
    { name: "Sauberkeit",      color: "#84CC16", icon: "broom" },
    { name: "Soziales",        color: "#F59E0B", icon: "hands-helping" },
    { name: "Sicherheit",      color: "#EF4444", icon: "shield-alt" },
    { name: "Wirtschaft",      color: "#6366F1", icon: "store" },
    { name: "Bildung",         color: "#EC4899", icon: "graduation-cap" },
    { name: "Digitales",       color: "#14B8A6", icon: "wifi" }
  ].freeze

  SENTIMENTS = [
    { name: "Sehr positiv",  color: "#86efac" },
    { name: "Positiv",       color: "#bbf7d0" },
    { name: "Neutral",       color: "#e5e7eb" },
    { name: "Kritisch",      color: "#fcd34d" },
    { name: "Sehr kritisch", color: "#fca5a5" }
  ].freeze

  THEMES = [
    { slug: "green-spaces",  description: "Urbane Grünflächen, Parks, Stadtbäume, Biodiversität in der Münchner Innenstadt" },
    { slug: "mobility",      description: "Öffentlicher Nahverkehr, Fahrradinfrastruktur, Fußgängerzonen und Verkehrsberuhigung" },
    { slug: "culture",       description: "Kulturveranstaltungen, Straßenkunst, Begegnungsorte und Aufführungsräume in der Innenstadt" },
    { slug: "climate",       description: "Klimaanpassung, Energieeffizienz, Hitzeschutz, Müllvermeidung und Recycling" },
    { slug: "cleanliness",   description: "Stadtsauberkeit, Mülleimerausstattung, Straßenpflege, Beleuchtung und Graffitientfernung" },
    { slug: "social",        description: "Soziale Dienste, Inklusion, Barrierefreiheit, Unterstützung für Senior:innen und Wohnungslose" },
    { slug: "safety",        description: "Verkehrssicherheit, sichere Schulwege, ausreichende Beleuchtung und subjektives Sicherheitsgefühl" },
    { slug: "economy",       description: "Lokale Wirtschaft, kleine Geschäfte, Wochenmärkte, Belebung von Ladenflächen" },
    { slug: "education",     description: "Lernorte, Bibliotheken, außerschulische Bildung und niederschwellige Angebote" },
    { slug: "digital",       description: "Digitale Infrastruktur, kostenloses WLAN, Smart-City-Anwendungen und digitale Teilhabe" }
  ].freeze

  PROPOSALS_PER_BATCH = 3
  COMMENTS_PER_PROPOSAL = 3

  def self.call(projekt_phase_id)
    new(projekt_phase_id).call
  end

  def initialize(projekt_phase_id)
    @phase = ProjektPhase.find(projekt_phase_id)
    @users = User.where.not(email: nil).limit(30).to_a
  end

  def call
    if @users.empty?
      puts "No users found"
      return
    end

    puts "Phase: ##{@phase.id} '#{@phase.title}' (projekt: #{@phase.projekt.title})"
    puts "Available users: #{@users.size}"

    puts "\nSeeding labels and sentiments..."
    seed_taxonomy

    @labels = @phase.projekt_labels.includes(:translations).to_a
    @sentiments = @phase.sentiments.includes(:translations).to_a

    puts "  Labels on phase:     #{@labels.size}"
    puts "  Sentiments on phase: #{@sentiments.size}"

    total_proposals = 0
    total_comments = 0
    total_labelings = 0

    THEMES.each_with_index do |theme, i|
      puts "\n=== Batch #{i + 1}/#{THEMES.size} — #{theme[:slug]} ==="
      batch = generate_batch(theme)
      next if batch.nil?

      batch.each do |item|
        result = persist_item(item)
        total_proposals += result[:proposal]
        total_comments += result[:comments]
        total_labelings += result[:labelings]
      end
    end

    puts "\n✓ Done!"
    puts "  Proposals created: #{total_proposals}"
    puts "  Comments created:  #{total_comments}"
    puts "  Labels assigned:   #{total_labelings}"
  end

  private

    def seed_taxonomy
      I18n.with_locale(:de) do
        LABELS.each do |spec|
          existing = @phase.projekt_labels
                          .joins(:translations)
                          .where(projekt_label_translations: { name: spec[:name] })
                          .first
          next if existing

          ProjektLabel.create!(
            projekt_phase: @phase,
            color: spec[:color],
            icon: spec[:icon],
            name: spec[:name]
          )
          puts "  + Label: #{spec[:name]}"
        end

        SENTIMENTS.each do |spec|
          existing = @phase.sentiments
                          .joins(:translations)
                          .where(sentiment_translations: { name: spec[:name] })
                          .first
          next if existing

          Sentiment.create!(
            projekt_phase: @phase,
            color: spec[:color],
            name: spec[:name]
          )
          puts "  + Sentiment: #{spec[:name]}"
        end
      end
    end

    def generate_batch(theme)
      labels_list = @labels.map { |l| "id=#{l.id} name=#{l.name}" }.join(", ")
      sentiments_list = @sentiments.map { |s| "id=#{s.id} name=#{s.name}" }.join(", ")

      prompt = <<~TEXT
        Du erzeugst realistische Seed-Daten für eine Bürgerbeteiligungsplattform der Stadt München (Innenstadt-Projekt).

        FOKUS DIESES BATCHES: #{theme[:description]}

        Erzeuge #{PROPOSALS_PER_BATCH} realistische Bürgervorschläge auf DEUTSCH. Jeder Vorschlag enthält:
        - title: 5–15 Wörter, prägnant
        - description: 80–120 Wörter, konkret und umsetzungsorientiert
        - label_id: eine ID aus der Labelliste, die thematisch am besten passt
        - sentiment_id: eine ID aus der Sentimentliste (oder null)
        - comments: ein Array mit #{COMMENTS_PER_PROPOSAL} kurzen Bürgerkommentaren (je 1–2 Sätze auf Deutsch). MISCHE die Tonalität: mindestens ein positiver, ein kritischer und ein neutraler Kommentar.

        Verfügbare Labels (nutze die IDs): #{labels_list}
        Verfügbare Sentiments (nutze die IDs): #{sentiments_list}

        Antwort ausschließlich als valides JSON-Array, exakt #{PROPOSALS_PER_BATCH} Objekte:
        [
          {
            "title": "...",
            "description": "...",
            "label_id": <int>,
            "sentiment_id": <int oder null>,
            "comments": ["...", "...", "..."]
          }
        ]
      TEXT

      response = Ai::RubyLlmFactory.chat.ask(prompt)
      data = parse_json(response.content)

      unless data.is_a?(Array)
        puts "  ✗ Parsing failed"
        return nil
      end

      puts "  + #{data.size} proposals generated"
      data
    rescue StandardError => e
      puts "  ✗ AI call error: #{e.message}"
      nil
    end

    def persist_item(item)
      user = @users.sample

      proposal = Proposal.create!(
        projekt_phase: @phase,
        author: user,
        title: item["title"].to_s,
        description: item["description"].to_s,
        responsible_name: user.username || user.email,
        resource_terms: true,
        published_at: Time.current,
        admin_accepted: true
      )

      labelings = 0
      label = @labels.find { |l| l.id == item["label_id"] }
      if label
        ProjektLabeling.create!(projekt_label: label, labelable: proposal)
        labelings = 1
      end

      sentiment = @sentiments.find { |s| s.id == item["sentiment_id"] }
      proposal.update!(sentiment: sentiment) if sentiment

      comment_count = 0
      Array(item["comments"]).each do |body|
        next if body.to_s.strip.empty?

        Comment.create!(commentable: proposal, user: @users.sample, body: body.to_s)
        comment_count += 1
      end

      puts "    + #{proposal.title.truncate(60)} [#{label&.name || "—"} / #{sentiment&.name || "—"}] +#{comment_count}c"
      { proposal: 1, comments: comment_count, labelings: labelings }
    rescue StandardError => e
      puts "    ✗ persist error: #{e.message}"
      { proposal: 0, comments: 0, labelings: 0 }
    end

    def parse_json(content)
      cleaned = content.strip.gsub(/\A```(json)?\s*/, "").gsub(/\s*```\z/, "")

      start_idx = cleaned.index("[")
      end_idx = cleaned.rindex("]")
      cleaned = cleaned[start_idx..end_idx] if start_idx && end_idx

      JSON.parse(cleaned)
    rescue JSON::ParserError => e
      puts "  JSON parse error: #{e.message}"
      puts "  Content (first 300 chars): #{content[0..300]}"
      nil
    end
end

if __FILE__ == $0
  if ARGV[0].nil?
    puts "Usage: rails runner lib/scripts/ai/seed_phase_proposals_with_labels.rb PROJEKT_PHASE_ID"
    exit 1
  end

  projekt_phase_id = ARGV[0].to_i
  Ai::SeedPhaseProposalsWithLabels.call(projekt_phase_id)
end
