module MunicipalPlans
  class LegacyImport
    # Splits the legacy "Absätze" block along its sub-headings. A block whose headings are not all
    # known is never split at a guess: it is kept whole and its offending headings are named.
    class TextBlock
      HEADING = %r{<h([1-6])\b[^>]*>(.*?)</h\1\s*>}mi
      PARAGRAPH = %r{<p\b[^>]*>(.*?)</p\s*>}mi
      PARTICIPATION_LINE = /\A(formell|informell)\s*:\s*(ja|nein)\b\.?\s*(.*)\z/mi

      SECTIONS = {
        "Letzter Beschluss zum Vorhaben" => :last_resolution,
        "Aktueller Bearbeitungsstand" => :processing_status,
        "Geplanter Zeitpunkt der Umsetzung / nächste Schritte" => :next_steps,
        "Kosten soweit bezifferbar" => :costs,
        "Betroffenes Gebiet" => :dropped,
        "Schwerpunktmäßig betroffene Themen" => :dropped,
        "Bürgerbeteiligung" => :participation
      }.freeze

      attr_reader :fields, :participation, :unknown_headings, :notes

      def initialize(html)
        @html = html.to_s
        @fields = {}
        @participation = {}
        @unknown_headings = []
        @notes = []
        split
      end

      def split?
        unknown_headings.empty?
      end

      private

        attr_reader :html

        def split
          preamble, *rest = html.split(HEADING, -1)
          sections = rest.each_slice(3).map do |level, heading, body|
            [level, normalize_heading(heading), body]
          end

          @unknown_headings = unknown(sections)
          return keep_whole unless unknown_headings.empty?

          fields[:further_information] = MunicipalPlans::LegacyImport::Html.to_plain_text(preamble)
          sections.each { |_, heading, body| assign(SECTIONS[heading], body) }
        end

        def unknown(sections)
          seen = []

          sections.filter_map do |level, heading, _|
            known = level == "3" && SECTIONS.key?(heading) && seen.exclude?(heading)
            seen << heading
            "<h#{level}>#{heading}" unless known
          end
        end

        def keep_whole
          @fields = { further_information: MunicipalPlans::LegacyImport::Html.to_plain_text(html) }
          @participation = {}
        end

        def normalize_heading(heading)
          text = heading.gsub(MunicipalPlans::LegacyImport::Html::BREAK, " ")
          text = MunicipalPlans::LegacyImport::Html.single_line(text).to_s
          text.gsub(/(?<!\S)[-–](?!\S)/, " ").squish
        end

        def assign(field, body)
          case field
          when :costs
            costs = MunicipalPlans::LegacyImport::Html.single_line(body)
            fields[:costs] = costs unless costs.nil? || costs.match?(/\A[-–]+\z/)
          when :participation
            parse_participation(body)
          when :dropped
            nil
          else
            fields[field] = MunicipalPlans::LegacyImport::Html.to_plain_text(body)
          end
        end

        def parse_participation(body)
          reasons = { formal: [], informal: [] }
          current = nil

          if MunicipalPlans::LegacyImport::Html.to_plain_text(body.gsub(PARAGRAPH, "")).present?
            return unparsed_participation(body, "text outside of paragraphs")
          end

          body.scan(PARAGRAPH).flatten.each do |paragraph|
            head, tail = paragraph.split(MunicipalPlans::LegacyImport::Html::BREAK, 2)
            match = MunicipalPlans::LegacyImport::Html.single_line(head).to_s.match(PARTICIPATION_LINE)

            if match
              current = match[1].casecmp?("formell") ? :formal : :informal
              participation[current] = match[2].casecmp?("ja")
              reasons[current] = [match[3], tail]
            elsif MunicipalPlans::LegacyImport::Html.to_plain_text(paragraph).blank?
              next
            elsif current
              reasons[current] << paragraph
            else
              return unparsed_participation(body, "paragraph without \"Formell:\"/\"Informell:\"")
            end
          end

          return unparsed_participation(body, "no \"Formell:\"/\"Informell:\" found") if current.nil?

          fields[:formal_participation_reason] = reason_text(reasons[:formal])
          fields[:informal_participation_reason] = reason_text(reasons[:informal])
        end

        def unparsed_participation(body, reason)
          participation.clear
          notes << "Bürgerbeteiligung: #{reason}"

          text = MunicipalPlans::LegacyImport::Html.to_plain_text(body)
          return if text.blank?

          fields[:further_information] = [fields[:further_information], "Bürgerbeteiligung:\n#{text}"]
                                         .compact_blank.join("\n\n")
        end

        def reason_text(parts)
          texts = parts.compact.map { |part| MunicipalPlans::LegacyImport::Html.to_plain_text(part) }
          texts.compact_blank.join("\n\n").presence
        end
    end
  end
end
