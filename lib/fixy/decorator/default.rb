module Fixy
  module Decorator
    class Default
      class << self
        def document(document) = document
        def field(value, *_) = value
        def record(record) = record
      end
    end
  end
end
