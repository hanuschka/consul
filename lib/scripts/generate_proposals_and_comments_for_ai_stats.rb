require 'json'

class GenerateProposalsAndCommentsForAiStats
  def self.call(projekt_phase_id)
    new(projekt_phase_id).call
  end

  def initialize(projekt_phase_id)
    @projekt_phase = ProjektPhase.find(projekt_phase_id)
    @users = User.where.not(email: nil).limit(20).to_a
    @proposals = []
  end

  def call
    if @users.empty?
      puts "No users found"
      return
    end

    puts "Generating proposals for phase: #{@projekt_phase.title}"
    generate_proposals

    puts "\nGenerating comments for proposals..."
    generate_comments_for_proposals

    puts "\n✓ Done!"
    puts "  Created #{@proposals.count} proposals"
    puts "  Created #{Comment.where(commentable: @proposals).count} comments"
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

  def generate_proposals
    num_proposals = 3

    content_blocks_text = extract_content_blocks_text

    prompt = <<~TEXT
      Generate #{num_proposals} realistic proposal ideas for a civic participation project.

      Project Context:
      - Phase Name: #{@projekt_phase.phase_tab_name || @projekt_phase.title}
      - Project Name: #{@projekt_phase.projekt.title}
      - Welcome Text: #{@projekt_phase.welcome_text_in_show}

      Project Content:
      #{content_blocks_text}

      Each proposal should be relevant to this project's theme and content. Use the context above to understand what the project is about.
      Make the proposals realistic and varied - some simple, some more complex.

      Return a JSON array of proposals. Each proposal should have:
      - title: A clear, concise title (in German)
      - description: A detailed description explaining the proposal (approximately 100 words in German)

      Return ONLY valid JSON in this format:
      [
        {"title": "Title 1", "description": "Description 1"},
        {"title": "Title 2", "description": "Description 2"}
      ]
    TEXT

    response = Ai::RubyLlmFactory.chat.ask(prompt)
    proposals_data = parse_json_response(response.content)

    if proposals_data.is_a?(Array)
      proposals_data.each do |proposal_data|
        create_proposal(proposal_data)
      end
      puts "  ✓ Created #{proposals_data.length} proposals"
    else
      puts "  ✗ Failed to parse AI response for proposals"
    end
  rescue => e
    puts "  ✗ Error generating proposals: #{e.message}"
  end

  def create_proposal(data)
    user = @users.sample

    proposal = Proposal.create!(
      projekt_phase: @projekt_phase,
      author: user,
      title: data['title'],
      description: data['description'],
      responsible_name: user.username || user.email
    )

    @proposals << proposal
    puts "    Created: #{proposal.title}"
  rescue => e
    puts "    ✗ Failed to create proposal: #{e.message}"
  end

  def generate_comments_for_proposals
    @proposals.each do |proposal|
      puts "  Generating comments for: #{proposal.title}"
      generate_comments_for_proposal(proposal)
    end
  end

  def generate_comments_for_proposal(proposal)
    num_comments = rand(5..7)

    prompt = <<~TEXT
      Generate #{num_comments} realistic user comments for the following proposal. Mix positive, arguing, and negative feedback.

      Proposal Title: #{proposal.title}
      Proposal Description: #{proposal.description}

      Return a JSON array of comments. Each comment should be a German text string (2-4 sentences) that provides feedback on the proposal.
      Mix the tone: some should be positive/supportive, some should be critical/arguing, and some should be negative.
      Make them sound like real citizen feedback on a civic participation platform.

      Return ONLY valid JSON in this format:
      ["comment text 1", "comment text 2", ...]
    TEXT

    response = Ai::RubyLlmFactory.chat.ask(prompt)
    comments_data = parse_json_response(response.content)

    if comments_data.is_a?(Array)
      comments_data.each do |comment_text|
        create_comment(proposal, comment_text)
      end
      puts "    ✓ Created #{comments_data.length} comments"
    else
      puts "    ✗ Failed to parse AI response"
    end
  rescue => e
    puts "    ✗ Error: #{e.message}"
  end

  def create_comment(proposal, body)
    user = @users.sample

    Comment.create!(
      commentable: proposal,
      user: user,
      body: body
    )
  end

  def parse_json_response(content)
    cleaned = content.strip
    cleaned = cleaned.gsub(/^```json\s*/, '').gsub(/\s*```$/, '')
    cleaned = cleaned[cleaned.index('[')..cleaned.rindex(']')] if cleaned.include?('[')

    JSON.parse(cleaned)
  rescue JSON::ParserError => e
    puts "    JSON parse error: #{e.message}"
    puts "    Content: #{content[0..200]}"
    nil
  end
end

if __FILE__ == $0
  if ARGV[0].nil?
    puts "Usage: rails runner lib/scripts/generate_proposals_and_comments_for_ai_stats.rb PROJEKT_PHASE_ID"
    exit 1
  end

  projekt_phase_id = ARGV[0].to_i
  GenerateProposalsAndCommentsForAiStats.call(projekt_phase_id)
end
