class Ai::GenerateContentBlock < ApplicationService
  def initialize(instructions, content_block_html)
    @instructions = instructions
    @content_block_html = content_block_html
  end

  def call
    llm_response =
      Ai::RubyLlmFactory
        .chat_with_json_output(output_schema)
        .ask(
          <<~TEXT
            Update the content block html using provided instructions.
            If explicitly asked to add some widget or UI elements use Zurb Foundation 6.
            Instructions: '#{@instructions}'.
            When requested to add images use "https://placehold.co" for src.
            Dont replace existing images. Don't wrap image blocks with figure element.
            For instance: "https://placehold.co/275x275".

            Current content block html content:
            #{@content_block_html}

            Return just new html.
          TEXT
        )

    llm_response.content["html"]
  end

  def output_schema
    {
      type: 'object',
      properties: {
        html: { type: 'string' },
      },
      required: ['html'],
      additionalProperties: false
    }
  end
end
