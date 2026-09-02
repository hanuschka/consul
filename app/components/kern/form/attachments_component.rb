class Kern::Form::AttachmentsComponent < ApplicationComponent
  def initialize(form:, attribute:, max: 10, accept: [], attached: [], remove_path: nil)
    @form = form
    @attribute = attribute
    @max = max
    @accept = accept
    @attached = attached
    @remove_path = remove_path
  end

  private

    def field_name
      "#{@form.object_name}[#{@attribute}][]"
    end

    def accept_attribute
      Array(@accept).join(",")
    end

    def attached_documents
      @attached.to_a
    end

    def remaining_slots
      [@max.to_i - attached_documents.size, 0].max
    end

    def remove_path_for(attachment)
      @remove_path&.call(attachment)
    end
end
