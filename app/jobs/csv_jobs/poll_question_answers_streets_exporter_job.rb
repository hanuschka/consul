class CsvJobs::PollQuestionAnswersStreetsExporterJob < ApplicationJob
  queue_as :default

  def perform(exporting_user_id, question_id)
    @exporting_user = User.find(exporting_user_id)
    @poll_question = Poll::Question.find(question_id)

    file_name = "poll_question_#{question_id}_answers_streets_#{Time.zone.now.strftime("%Y-%m-%d-%H-%M")}.csv"
    file_path = "tmp/#{file_name}"

    File.write(
      Rails.root.join(file_path),
      CsvServices::PollQuestionAnswersStreetsExporter.call(@poll_question)
    )

    Mailer.file_ready(@exporting_user, file_name, file_path).deliver_later
  end
end
