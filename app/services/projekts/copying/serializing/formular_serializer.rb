class Projekts::Copying::Serializing::FormularSerializer < ApplicationService
  def initialize(source_phase:)
    @source_phase = source_phase
  end

  def call
    formular = Formular.find_by(projekt_phase_id: source_phase.id)
    return nil if formular.blank?

    {
      "fields" => serialize_all(formular.formular_fields),
      # sent_at records a send that happened for the source's recipients.
      "follow_up_letters" => serialize_all(
        formular.formular_follow_up_letters, except: %w[sent_at]
      )
    }
  end

  private

    attr_reader :source_phase

    def serialize_all(records, except: [])
      records.map do |record|
        Projekts::Copying::Serializing::RecordSerializer.call(record, except: except)
      end
    end
end
