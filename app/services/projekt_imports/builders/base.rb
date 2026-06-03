class ProjektImports::Builders::Base
  attr_reader :projekt, :phase, :payload

  def initialize(projekt:, phase:, payload:)
    @projekt = projekt
    @phase = phase
    @payload = payload
  end

  def self.call(**kwargs)
    new(**kwargs).call
  end

  def call
    raise NotImplementedError
  end
end

class ProjektImports::Builders::BuilderError < StandardError; end
