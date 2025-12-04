require 'json'

class Ai::GenerateInvestmentsAndCommentsForAiStats
  def self.call(projekt_phase_id)
    new(projekt_phase_id).call
  end

  def initialize(projekt_phase_id)
    @projekt_phase = ProjektPhase.find(projekt_phase_id)
    @budget = @projekt_phase.budget
    @users = User.where.not(email: nil).limit(20).to_a
    @investments = []
    @labels = @projekt_phase.projekt_labels.includes(:translations).to_a
    @sentiments = @projekt_phase.sentiments.includes(:translations).to_a
  end

  def call
    if @users.empty?
      puts "No users found"
      return
    end

    unless @budget
      puts "No budget found for this projekt phase"
      return
    end

    unless @budget.heading
      puts "Budget has no heading"
      return
    end

    puts "Generating investments for budget: #{@budget.name}"
    puts "  Available labels: #{@labels.count}"
    puts "  Available sentiments: #{@sentiments.count}"
    generate_investments

    puts "\nGenerating comments for investments..."
    generate_comments_for_investments

    puts "\n✓ Done!"
    puts "  Created #{@investments.count} investments"
    puts "  Created #{Comment.where(commentable: @investments).count} comments"

    total_labels = ProjektLabeling.where(labelable: @investments).count
    total_sentiments = @investments.where.not(sentiment_id: nil).count
    puts "  Assigned #{total_labels} labels" if total_labels > 0
    puts "  Assigned #{total_sentiments} sentiments" if total_sentiments > 0
  end

  private

  def extract_content_blocks_text
    content_blocks = @projekt_phase.projekt.content_blocks
    return "No additional content available." if content_blocks.empty?

    content_blocks.map do |block|
      sanitized = ActionView::Base.full_sanitizer.sanitize(block.body)
      "#{block.name}: #{sanitized.truncate(500)}"
    end.join("\n\n")
  end

  def generate_investments
    num_investments = 3

    content_blocks_text = extract_content_blocks_text

    prompt = <<~TEXT
      Generate #{num_investments} realistic budget investment ideas for a civic participation project.

      Project Context:
      - Phase Name: #{@projekt_phase.phase_tab_name || @projekt_phase.title}
      - Project Name: #{@projekt_phase.projekt.title}
      - Budget Name: #{@budget.name}
      - Welcome Text: #{@projekt_phase.welcome_text_in_show}

      Project Content:
      #{content_blocks_text}

      Each investment should be relevant to this project's theme and content. Use the context above to understand what the project is about.
      Make the investments realistic and varied - some simple, some more complex.
      These are budget investments that citizens can vote on, so they should represent concrete projects or initiatives that require funding.

      Return a JSON array of investments. Each investment should have:
      - title: A clear, concise title (in German)
      - description: A detailed description explaining the investment (approximately 100 words in German)

      Return ONLY valid JSON in this format:
      [
        {"title": "Title 1", "description": "Description 1"},
        {"title": "Title 2", "description": "Description 2"}
      ]
    TEXT

    response = Ai::RubyLlmFactory.chat.ask(prompt)
    investments_data = parse_json_response(response.content)

    if investments_data.is_a?(Array)
      investments_data.each do |investment_data|
        create_investment(investment_data)
      end
      puts "  ✓ Created #{investments_data.length} investments"
    else
      puts "  ✗ Failed to parse AI response for investments"
    end
  rescue => e
    puts "  ✗ Error generating investments: #{e.message}"
  end

  def create_investment(data)
    user = @users.sample

    investment = Budget::Investment.create!(
      budget: @budget,
      heading: @budget.heading,
      author: user,
      title: data['title'],
      description: data['description'],
      terms_of_service: true
    )

    assign_labels_and_sentiment(investment)

    @investments << investment
    puts "    Created: #{investment.title}"
  rescue => e
    puts "    ✗ Failed to create investment: #{e.message}"
  end

  def assign_labels_and_sentiment(investment)
    return if @labels.empty? && @sentiments.empty?

    labels_text = @labels.map { |l| "- #{l.name}: #{l.description}" }.join("\n")
    sentiments_text = @sentiments.map { |s| "- #{s.name}" }.join("\n")

    prompt = <<~TEXT
      Analyze the following budget investment and suggest which labels and sentiment best fit it.

      Investment:
      Title: #{investment.title}
      Description: #{investment.description}

      Available Labels:
      #{labels_text.presence || "None"}

      Available Sentiments:
      #{sentiments_text.presence || "None"}

      Return ONLY valid JSON with this exact format:
      {
        "label_ids": [array of label IDs that fit this investment],
        "sentiment_id": single sentiment ID that best matches (or null)
      }

      Label IDs available: #{@labels.map(&:id).join(', ')}
      Sentiment IDs available: #{@sentiments.map(&:id).join(', ')}
    TEXT

    response = Ai::RubyLlmFactory.chat.ask(prompt)
    data = parse_json_response(response.content)

    if data.is_a?(Hash)
      if data['label_ids'].is_a?(Array)
        data['label_ids'].each do |label_id|
          label = @labels.find { |l| l.id == label_id }
          if label
            ProjektLabeling.create!(
              projekt_label: label,
              labelable: investment
            )
            puts "      Assigned label: #{label.name}"
          end
        end
      end

      if data['sentiment_id']
        sentiment = @sentiments.find { |s| s.id == data['sentiment_id'] }
        if sentiment
          investment.update!(sentiment: sentiment)
          puts "      Assigned sentiment: #{sentiment.name}"
        end
      end
    end
  rescue => e
    puts "      ✗ Error assigning labels/sentiment: #{e.message}"
  end

  def generate_comments_for_investments
    @investments.each do |investment|
      puts "  Generating comments for: #{investment.title}"
      generate_comments_for_investment(investment)
    end
  end

  def generate_comments_for_investment(investment)
    num_comments = rand(2..3)

    prompt = <<~TEXT
      Generate #{num_comments} realistic user comments for the following budget investment. Mix positive, arguing, and negative feedback.

      Investment Title: #{investment.title}
      Investment Description: #{investment.description}

      Return a JSON array of comments. Each comment should be a German text string (1-2 sentences) that provides feedback on the investment.
      Mix the tone: some should be positive/supportive, some should be critical/arguing, and some should be negative.
      Make them sound like real citizen feedback on a civic participation platform regarding budget investments.

      Return ONLY valid JSON in this format:
      ["comment text 1", "comment text 2", ...]
    TEXT

    response = Ai::RubyLlmFactory.chat.ask(prompt)
    comments_data = parse_json_response(response.content)

    if comments_data.is_a?(Array)
      comments_data.each do |comment_text|
        create_comment(investment, comment_text)
      end
      puts "    ✓ Created #{comments_data.length} comments"
    else
      puts "    ✗ Failed to parse AI response"
    end
  rescue => e
    puts "    ✗ Error: #{e.message}"
  end

  def create_comment(investment, body)
    user = @users.sample

    Comment.create!(
      commentable: investment,
      user: user,
      body: body
    )
  end

  def parse_json_response(content)
    cleaned = content.strip
    cleaned = cleaned.gsub(/^```json\s*/, '').gsub(/\s*```$/, '')

    if cleaned.include?('{') && cleaned.include?('}')
      cleaned = cleaned[cleaned.index('{')..cleaned.rindex('}')]
    elsif cleaned.include?('[') && cleaned.include?(']')
      cleaned = cleaned[cleaned.index('[')..cleaned.rindex(']')]
    end

    JSON.parse(cleaned)
  rescue JSON::ParserError => e
    puts "    JSON parse error: #{e.message}"
    puts "    Content: #{content[0..200]}"
    nil
  end
end

if __FILE__ == $0
  if ARGV[0].nil?
    puts "Usage: rails runner lib/scripts/ai/generate_investments_and_comments_for_ai_stats.rb PROJEKT_PHASE_ID"
    exit 1
  end

  projekt_phase_id = ARGV[0].to_i
  Ai::GenerateInvestmentsAndCommentsForAiStats.call(projekt_phase_id)
end
