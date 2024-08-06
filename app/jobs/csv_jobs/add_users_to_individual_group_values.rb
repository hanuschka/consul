class CsvJobs::AddUsersToIndividualGroupValues < ApplicationJob
  queue_as :upload

  def perform(current_user_id, individual_group_value_id, csv_file_path)
    @individual_group_value = IndividualGroupValue.find(individual_group_value_id)
    @individual_group_value.add_from_csv(csv_file_path)

    Mailer.individual_group_value_users_added(current_user_id, @individual_group_value.id).deliver_later
  end
end
