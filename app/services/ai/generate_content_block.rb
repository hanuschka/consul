class Ai::GenerateContentBlock < ApplicationService
  def self.call(instructions, content_block_html)
    llm_response = RubyLLM.chat(model: 'gpt-5-nano').ask(
      <<~TEXT
        Update the content block html using provided instructions.
        Use Zurb foundation elements and styles when needed.
        Instructions: '#{instructions}'.
        When requested to add images use "https://placehold.co" for src.
        Dont replace existing images. Don't wrap image blocks with figure element.
        For instance: "https://placehold.co/275x275".

        Current content block html content:
        #{content_block_html}

        Return just new html.
      TEXT
    )

    llm_response.content
  end
end
