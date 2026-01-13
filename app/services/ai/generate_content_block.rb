class Ai::GenerateContentBlock < ApplicationService
  def initialize(instructions, content_block_html, title = nil, subtitle = nil)
    @instructions = instructions
    @content_block_html = content_block_html
    @title = title
    @subtitle = subtitle
  end

  def call
    llm_response =
      Ai::RubyLlmFactory
        .chat_with_json_output(output_schema)
        .ask(
          <<~TEXT
            Update the content block HTML strictly following the provided instructions.

            Hard rules:
            - Modify only what the instructions explicitly require. Do not restructure, reorder, remove, or wrap existing elements.
            - Preserve all existing HTML exactly as it is unless an instruction explicitly requires a change.
            - When adding UI elements, use Zurb Foundation 6 and inline styles.
            - When adding images, use "https://placehold.co" as src and DO NOT replace existing images.
            - DO NOT wrap images in figure elements and DO NOT alter existing figure elements.
            - Do not optimize, clean up, or reformat the HTML. Keep the original formatting and indentation unless an instruction requires otherwise.
            - Never infer desired changes. Only apply changes explicitly described in the instructions.

            Additional context of content block:
            It's content block of projekt with title: "#{@title}" and subtitle: "#{@subtitle}"

            Instructions: "#{@instructions}"

            Current content block HTML:
            #{@content_block_html}

            Return ONLY the updated HTML, without explanations.
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
