class WhatsappApi::Resources::ConversationalAutomation
  BASE_PATH = "/conversational_automation".freeze
  MAX_PROMPT_LENGTH = 80
  MAX_COMMANDS = 30
  MAX_COMMAND_NAME_LENGTH = 32
  MAX_COMMAND_DESCRIPTION_LENGTH = 256
  EMOJI = /[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE0F}\u{2190}-\u{21FF}]/

  def initialize(client)
    @client = client
  end

  def show
    @client.get(BASE_PATH)
  end

  def configure(enable_welcome_message:, prompts: [], commands: [])
    @client.post(
      BASE_PATH,
      body: {
        enable_welcome_message: enable_welcome_message,
        prompts: sanitized_prompts(prompts),
        commands: sanitized_commands(commands)
      }
    )
  end

  private

    # Ice breakers reject emoji outright, so they are stripped rather than left
    # to fail the whole configuration call.
    def sanitized_prompts(prompts)
      prompts
        .first(::Whatsapp::MAX_ICE_BREAKERS)
        .filter_map { |prompt| sanitized_prompt(prompt) }
    end

    def sanitized_prompt(prompt)
      prompt.to_s.gsub(EMOJI, "").squish.truncate(MAX_PROMPT_LENGTH).presence
    end

    def sanitized_commands(commands)
      commands.first(MAX_COMMANDS).map do |command|
        {
          command_name: command[:command_name].to_s.truncate(MAX_COMMAND_NAME_LENGTH),
          command_description:
            command[:command_description].to_s.truncate(MAX_COMMAND_DESCRIPTION_LENGTH)
        }
      end
    end
end
