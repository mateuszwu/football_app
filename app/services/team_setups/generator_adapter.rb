module TeamSetups
  class GeneratorAdapter
    def self.call(...)
      new(...).call
    end

    def call
      raise NotImplementedError, "#{self.class.name} must implement #call"
    end
  end
end
