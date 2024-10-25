class ApplicationService
  def self.call(*attributes, **key_args, &block)
    new(*attributes, **key_args).call(&block)
  end
end
