class Poll::Question::Stats::CsvExporter
  require "csv"

  def initialize(question)
    @question = question
  end

  def to_csv
    CSV.generate(headers: false, col_sep: ";") do |csv|
      csv << bam_street_headers(@question)

      BamStreet.all.find_each do |bam_street|
        csv << bam_street_row(@question, bam_street)
      end
    end
  end

  private

    def bam_street_headers(question)
      question.question_answers.map(&:title).unshift(question.title)
    end

    def bam_street_row(question, bam_street)
      row = []
      row.push(bam_street.name)

      question.question_answers.each do |qa|
        answer_count_by_street = question.answers
          .where(answer: qa.title)
          .joins(author: :bam_street)
          .where(bam_streets: { id: bam_street.id })
          .count
        row.push answer_count_by_street
      end

      row
    end
end
