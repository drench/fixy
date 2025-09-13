module Fixy
  class Record
    LINE_ENDING_LF = "\n".freeze
    LINE_ENDING_CR = "\r".freeze
    LINE_ENDING_CRLF = "#{LINE_ENDING_CR}#{LINE_ENDING_LF}".freeze
    DEFAULT_LINE_ENDING = LINE_ENDING_LF

    Field = Data.define(:name, :range, :type) do
      def from = range.begin
      def overlap?(other) = range.overlap?(other)
      def size = range.size
      def to = range.end
    end

    class << self
      def record_length(count = nil)
        @record_length ||= count
      end

      def line_ending(character = nil)
        if defined? @line_ending
          @line_ending
        elsif character.nil?
          DEFAULT_LINE_ENDING
        else
          @line_ending = character
        end
      end

      def field(name, size, range, type, &block)
        @record_fields ||= default_record_fields

        # Make sure inputs are valid, we rather fail early than behave unexpectedly later.
        raise ArgumentError, "Name '#{name}' is not a symbol" unless name.is_a? Symbol
        raise ArgumentError, "Size '#{size}' is not a numeric" unless size.is_a?(Numeric) && size.positive?
        raise ArgumentError, "Range '#{range}' is invalid" unless range.is_a?(Range)
        raise ArgumentError, "Unknown type '#{type}'" unless (private_instance_methods + instance_methods).include? :"format_#{type}"

        raise ArgumentError, "Invalid Range (size: #{size}, range: #{range})" if range.size != size
        raise ArgumentError, "Invalid Range (> #{record_length})" unless range.end <= record_length

        # Ensure range is not already covered by another definition
        (1..range.end).each do |column|
          if @record_fields[column]&.overlap?(range)
            raise ArgumentError, "Column #{column} has already been allocated"
          end
        end

        # We're good to go :)
        @record_fields[range.begin] = Field.new(name:, range:, type:)

        field_value(name, block) if block
      end

      # Convenience method for creating field methods
      def field_value(name, value)
        # Make sure we're not overriding an existing method
        if (private_instance_methods + instance_methods).include?(name)
          raise ArgumentError, "Method '#{name}' is already defined, watch out for conflicts."
        end

        if value.is_a? Proc
          define_method(name) { instance_exec(&value) }
        else
          define_method(name) { value }
        end
      end

      attr_reader :record_fields

      def default_record_fields
        if superclass.respond_to?(:record_fields, true) && superclass.record_fields
          superclass.record_fields.dup
        else
          {}
        end
      end

      # Parse an existing record
      def parse(record, debug = false)
        raise ArgumentError, "Record must be a string" unless record.is_a? String

        unless record.bytesize == record_length
          raise ArgumentError, "Record length is invalid (Expected #{record_length})"
        end

        decorator = debug ? Fixy::Decorator::Debug : Fixy::Decorator::Default
        fields = []
        output = ""
        current_position = 1
        current_record = 1

        byte_record = record.bytes.to_a
        while current_position <= record_length

          field = record_fields[current_position]
          raise StandardError, "Undefined field for position #{current_position}" if field.nil?

          # Extract field data from existing record
          from = field.from - 1
          to = field.to - 1
          value = byte_record[from..to].pack("C*").force_encoding("utf-8")

          formatted_value = decorator.field(value, current_record, current_position, field.name, field.size, field.type)
          output << formatted_value
          fields << {name: field.name, value: value}

          current_position = field.to + 1
          current_record += 1
        end

        # Documentation mandates that every record ends with new line.
        output << line_ending

        {fields: fields, record: decorator.record(output)}
      end
    end

    # Generate the entry based on the record structure
    def generate(debug = false)
      decorator = debug ? Fixy::Decorator::Debug : Fixy::Decorator::Default
      output = []
      current_position = 1
      current_record = 1

      while current_position <= self.class.record_length
        field = record_fields[current_position]
        raise StandardError, "Undefined field for position #{current_position}" if field.nil?

        # We will first retrieve the value, then format it
        value = public_send(field.name)
        formatted_value = public_send(:"format_#{field.type}", value, field.size)
        formatted_value = decorator.field(formatted_value, current_record, current_position, field.name, field.size, field.type)

        output.push(formatted_value)
        current_position = field.to + 1
        current_record += 1
      end

      # Documentation mandates that every record ends with new line.
      output.push(line_ending)

      # All ready. In the words of Mr. Peters: "Take it and go!"
      decorator.record(output.join)
    end

    private

    # Retrieves the list of record fields that were set through the class methods.
    def record_fields = self.class.record_fields

    # Retrieves the line ending for this record type
    def line_ending = self.class.line_ending
  end
end
