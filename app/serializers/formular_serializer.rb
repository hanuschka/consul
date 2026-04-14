class FormularSerializer < BaseSerializer
  attr_reader :formular

  def initialize(formular)
    @formular = formular
  end

  def serialize
    formular_data = formular.as_json(
      only: [
        :id,
        :projekt_phase_id,
        :created_at,
        :updated_at
      ]
    )

    if formular.projekt_phase.present?
      formular_data[:projekt_phase] = {
        id: formular.projekt_phase.id,
        title: formular.projekt_phase.phase_tab_name,
        type: formular.projekt_phase.type,
        projekt_id: formular.projekt_phase.projekt_id
      }

      if formular.projekt_phase.projekt.present?
        projekt = formular.projekt_phase.projekt
        formular_data[:projekt] = {
          id: projekt.id,
          title: projekt.page&.title || projekt.name
        }
      end
    end

    # Include formular fields count if available
    formular_data[:formular_fields_count] = formular.formular_fields.count if formular.respond_to?(:formular_fields)
    formular_data[:formular_answers_count] = formular.formular_answers.count if formular.respond_to?(:formular_answers)

    formular_data
  end

  def self.serialize_collection(formulars)
    formulars.map { |formular| new(formular).serialize }
  end
end
