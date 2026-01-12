require 'json'

class Ai::GeneratePollWithData
  NUM_QUESTIONS = 10
  NUM_VOTERS = 20

  def self.call(projekt_phase_id)
    new(projekt_phase_id).call
  end

  def initialize(projekt_phase_id)
    @projekt_phase = ProjektPhase.find(projekt_phase_id)
    @users = User.where.not(email: nil).limit(20).to_a
    @poll = nil
    @questions = []
  end

  def call
    puts "Generating poll for phase: #{@projekt_phase.title}"
    puts "Project: #{@projekt_phase.projekt.page.title}"

    generate_poll
    return unless @poll

    generate_questions
    simulate_votes_and_comments

    puts "\n✓ Done!"
    puts "  Poll: #{@poll.name}"
    puts "  Questions: #{@questions.count}"
    puts "  Voters: #{@poll.voters.count}"
    puts "  Comments: #{@poll.comments.count}"
  end

  private

  def extract_context_text
    content_blocks = @projekt_phase.projekt.content_blocks
    return "" if content_blocks.empty?

    content_blocks.map do |block|
      sanitized = ActionView::Base.full_sanitizer.sanitize(block.body)
      "#{block.name}: #{sanitized.truncate(300)}"
    end.join("\n")
  end

  def generate_poll
    context_text = extract_context_text

    prompt = <<~TEXT
      Generate a realistic poll for a civic participation project.

      Project Title (use as main inspiration): #{@projekt_phase.projekt.page.title}
      Phase: #{@projekt_phase.phase_tab_name || @projekt_phase.title}
      Description: #{@projekt_phase.description}
      Additional Context: #{context_text}

      Generate a poll with name and summary in English. The poll should be directly relevant to the project title.
      Keep it concise - name should be 3-6 words, summary 1-2 sentences.

      Return ONLY valid JSON:
      {"name": "Poll name", "summary": "Brief summary"}
    TEXT

    response = Ai::RubyLlmFactory.chat.ask(prompt)
    data = parse_json_response(response.content)

    if data.is_a?(Hash) && data['name']
      @poll = Poll.create!(
        projekt_phase: @projekt_phase,
        name: data['name'],
        summary: data['summary'],
        published: true
      )
      puts "  ✓ Created poll: #{@poll.name}"
    else
      puts "  ✗ Failed to generate poll data"
    end
  rescue => e
    puts "  ✗ Error creating poll: #{e.message}"
  end

  def generate_questions
    context_text = extract_context_text

    prompt = <<~TEXT
      Generate #{NUM_QUESTIONS} poll questions for civic participation.

      Project Title (use as main inspiration): #{@projekt_phase.projekt.page.title}
      Poll: #{@poll.name}
      Summary: #{@poll.summary}
      Additional Context: #{context_text}

      Create varied question types:
      - 4 yes/no questions
      - 4 multiple choice questions (3-4 options)
      - 2 rating questions

      All text in English. Keep titles short (max 80 chars), descriptions brief (1-2 sentences).

      Return ONLY valid JSON array:
      [
        {
          "title": "Question text?",
          "description": "Brief context",
          "type": "yes_no"
        },
        {
          "title": "Question text?",
          "description": "Brief context",
          "type": "multiple",
          "answers": ["Option 1", "Option 2", "Option 3"]
        },
        {
          "title": "Question text?",
          "description": "Brief context",
          "type": "rating"
        }
      ]
    TEXT

    response = Ai::RubyLlmFactory.chat.ask(prompt)
    questions_data = parse_json_response(response.content)

    if questions_data.is_a?(Array)
      questions_data.each_with_index do |q_data, index|
        create_question(q_data, index + 1)
      end
      puts "  ✓ Created #{@questions.count} questions"
    else
      puts "  ✗ Failed to parse questions"
    end
  rescue => e
    puts "  ✗ Error generating questions: #{e.message}"
  end

  def create_question(data, order)
    author = @users.sample

    question = Poll::Question.create!(
      poll: @poll,
      author: author,
      title: data['title'],
      description: data['description'],
      given_order: order
    )

    vote_type = case data['type']
                when 'yes_no' then 'unique'
                when 'multiple' then 'multiple'
                when 'rating' then 'rating_scale'
                else 'unique'
                end

    VotationType.create!(
      questionable: question,
      vote_type: vote_type,
      max_votes: vote_type == 'multiple' ? 2 : nil
    )

    answers = case data['type']
              when 'yes_no'
                ['Yes', 'No']
              when 'rating'
                ['1', '2', '3', '4', '5']
              else
                data['answers'] || ['Option A', 'Option B', 'Option C']
              end

    answers.each_with_index do |answer_title, idx|
      Poll::Question::Answer.create!(
        question: question,
        title: answer_title,
        given_order: idx + 1
      )
    end

    @questions << question
    puts "    Created: #{question.title.truncate(50)}"
  rescue => e
    puts "    ✗ Failed to create question: #{e.message}"
  end

  def simulate_votes_and_comments
    voters_count = [NUM_VOTERS, @users.size].min
    puts "  Simulating #{voters_count} voters with personalized comments..."

    @users.first(voters_count).each_with_index do |user, idx|
      user_votes = vote_for_user(user)
      next if user_votes.empty?

      generate_comment_for_user(user, user_votes)
      puts "    [#{idx + 1}/#{voters_count}] #{user.username || user.email}"
    end

    puts "  ✓ Simulated #{@poll.voters.count} voters with #{@poll.comments.count} comments"
  rescue => e
    puts "  ✗ Error simulating votes: #{e.message}"
  end

  def vote_for_user(user)
    user_votes = []

    @questions.each do |question|
      next if rand < 0.15

      answer_option = question.question_answers.sample
      next unless answer_option

      Poll::Answer.create!(
        question: question,
        author: user,
        answer: answer_option.title
      )

      user_votes << { question: question.title, answer: answer_option.title }
    end

    if user_votes.any?
      Poll::Voter.create!(
        poll: @poll,
        user: user,
        origin: 'web'
      )
    end

    user_votes
  rescue => e
    puts "    ✗ Vote error for user #{user.id}: #{e.message}"
    []
  end

  def generate_comment_for_user(user, user_votes)
    votes_summary = user_votes.map { |v| "- #{v[:question]} → #{v[:answer]}" }.join("\n")

    prompt = <<~TEXT
      Generate a single realistic comment from a citizen who participated in a poll.

      Project: #{@projekt_phase.projekt.page.title}
      Poll: #{@poll.name}

      This user voted:
      #{votes_summary}

      Based on their voting pattern, generate ONE comment (#{rand(1..7)} sentences) that reflects their opinions.
      The comment should be consistent with how they voted - if they voted positively, comment should be supportive; if negatively, comment should be critical.
      Write in English, realistic citizen tone. Vary the length naturally.

      Return ONLY the comment text, no JSON, no quotes.
    TEXT

    response = Ai::RubyLlmFactory.chat.ask(prompt)
    comment_body = response.content.strip.gsub(/^["']|["']$/, '')

    Comment.create!(
      commentable: @poll,
      user: user,
      body: comment_body
    )
  rescue => e
    puts "    ✗ Comment error for user #{user.id}: #{e.message}"
  end

  def parse_json_response(content)
    cleaned = content.strip
    cleaned = cleaned.gsub(/^```json\s*/, '').gsub(/\s*```$/, '')

    if cleaned.include?('{') && cleaned.include?('}') && !cleaned.start_with?('[')
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
    puts "Usage: rails runner lib/scripts/ai/generate_poll_with_data.rb PROJEKT_PHASE_ID"
    exit 1
  end

  projekt_phase_id = ARGV[0].to_i
  Ai::GeneratePollWithData.call(projekt_phase_id)
end
