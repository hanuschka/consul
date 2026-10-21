module MunicipalPlansHelper
  LIST_ITEM = /\A\s*[-–•*]\s+(?=\S)/

  def municipal_plan_text(text)
    paragraphs = text.to_s.gsub(/\r\n?/, "\n").split(/\n\n+/).map { |paragraph| paragraph.split("\n") }
    return simple_format(text) if paragraphs.flatten.none? { |line| line.match?(LIST_ITEM) }

    safe_join(paragraphs.flat_map { |lines| municipal_plan_text_blocks(lines) }, "\n\n")
  end

  private

    def municipal_plan_text_blocks(lines)
      lines.chunk_while { |line, next_line| line.match?(LIST_ITEM) == next_line.match?(LIST_ITEM) }
           .filter_map do |run|
        if run.first.match?(LIST_ITEM)
          tag.ul(safe_join(run.map { |line| tag.li(sanitize(line.sub(LIST_ITEM, "").strip)) }))
        elsif run.join.present?
          simple_format(run.join("\n"))
        end
      end
    end
end
