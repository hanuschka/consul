require 'json'

class Ai::GenerateCommentsForProjektPhase
  def self.call(projekt_phase_id, num_comments: 10)
    new(projekt_phase_id, num_comments: num_comments).call
  end

  def initialize(projekt_phase_id, num_comments: 10)
    @projekt_phase = ProjektPhase.find(projekt_phase_id)
    @num_comments = num_comments
    @users = User.where.not(email: nil).limit(20).to_a
  end

  def call
    if @users.empty?
      puts "No users found"
      return
    end

    unless @projekt_phase.is_a?(ProjektPhase::CommentPhase)
      puts "Error: This is not a comment phase (type: #{@projekt_phase.type})"
      return
    end

    puts "Generating comments for comment phase: #{@projekt_phase.title}"
    puts "  Number of comments: #{@num_comments}"

    generate_comments

    puts "\n✓ Done!"
    puts "  Created #{@projekt_phase.comments.count} comments total"
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

  def generate_comments
    content_blocks_text = extract_content_blocks_text

    prompt = <<~TEXT
      Generate #{@num_comments} realistic user comments for a civic participation project comment phase.

      Project Context:
      - Phase Name: #{@projekt_phase.phase_tab_name || @projekt_phase.title}
      - Project Name: #{@projekt_phase.projekt.title}
      - Welcome Text: #{@projekt_phase.welcome_text_in_show}

      Project Content:
      #{content_blocks_text}

      This is a comment phase where citizens can leave their thoughts, opinions, and feedback about the project.
      Each comment should be relevant to this project's theme and content. Use the context above to understand what the project is about.

      Return a JSON array of comments. Each comment should be a German text string (1-3 sentences).
      Mix the tone: some should be positive/supportive, some should be critical/arguing, some should be negative, and some should be neutral/informative.
      Make them sound like real citizen feedback on a civic participation platform.
      Make the comments varied - some simple, some more detailed.

      Return ONLY valid JSON in this format:
      ["comment text 1", "comment text 2", ...]
    TEXT

    response = Ai::RubyLlmFactory.chat.ask(prompt)
    comments_data = parse_json_response(response.content)

    if comments_data.is_a?(Array)
      comments_data.each do |comment_text|
        create_comment(comment_text)
      end
      puts "  ✓ Created #{comments_data.length} comments"
    else
      puts "  ✗ Failed to parse AI response for comments"
    end
  rescue => e
    puts "  ✗ Error generating comments: #{e.message}"
  end

  def create_comment(body)
    user = @users.sample

    Comment.create!(
      commentable: @projekt_phase,
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
    puts "Usage: rails runner lib/scripts/ai/generate_comments_for_projekt_phase.rb PROJEKT_PHASE_ID [NUM_COMMENTS]"
    puts ""
    puts "Arguments:"
    puts "  PROJEKT_PHASE_ID  - Required: ID of the projekt phase (must be a CommentPhase)"
    puts "  NUM_COMMENTS      - Optional: Total number of comments to generate (default: 10)"
    puts ""
    puts "Examples:"
    puts "  rails runner lib/scripts/ai/generate_comments_for_projekt_phase.rb 123"
    puts "  rails runner lib/scripts/ai/generate_comments_for_projekt_phase.rb 123 20"
    exit 1
  end

  projekt_phase_id = ARGV[0].to_i
  num_comments = ARGV[1]&.to_i || 10

  Ai::GenerateCommentsForProjektPhase.call(projekt_phase_id, num_comments: num_comments)
end
