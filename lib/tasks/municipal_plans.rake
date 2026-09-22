namespace :municipal_plans do
  desc "Archives Vorhaben whose Archivdatum has come, where the instance asked for it"
  task apply_due_archiving: :environment do
    archived = MunicipalPlan.apply_due_archiving!

    puts "archived #{archived.size} Vorhaben"
  end
end
