class Kern::SwitchComponent < ApplicationComponent
  def initialize(
    label:, name: nil, id: nil, checked: false,
    description: nil, row: false, input_data: {}
  )
    @label = label
    @name = name
    @id = id
    @checked = checked
    @description = description
    @row = row
    @input_data = input_data
  end

  private

    attr_reader :label, :name, :id, :checked, :description, :input_data

    def css_classes
      class_names("kern-switch", "-row": @row)
    end

    def input_tag
      if name.present?
        check_box_tag(name, "1", checked, id: id, class: "kern-switch__input", data: input_data)
      else
        tag.input(type: "checkbox", class: "kern-switch__input", checked: checked, data: input_data)
      end
    end
end
