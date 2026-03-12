class Kern::FlashComponent < ApplicationComponent
  def initialize(flash:)
    @flash = flash
  end

  private

    def messages
      @flash.map do |type, message|
        { type: type.to_s, message: message, variant: variant_for(type) }
      end
    end

    def variant_for(type)
      case type.to_s
      when "notice" then "success"
      when "alert"  then "danger"
      else "info"
      end
    end
end
