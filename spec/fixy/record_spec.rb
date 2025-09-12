describe Fixy::Record do
  context "when the definition is correct" do
    it "raises no exception" do
      expect {
        Class.new(described_class) do
          include Fixy::Formatter::Alphanumeric

          record_length 20

          line_ending Fixy::Record::LINE_ENDING_CRLF

          field :first_name, 10, 1..10, :alphanumeric
          field :last_name, 10, 11..20, :alphanumeric
        end
      }.not_to raise_error
    end
  end

  context "when defining the same field more than once" do
    it "raises an exception" do
      expect {
        Class.new(described_class) do
          include Fixy::Formatter::Alphanumeric

          record_length 20
          field_value :first_name, -> { "Sarah" }
          field_value :first_name, -> { "Sarah" }
        end
      }.to raise_error(ArgumentError, /Method 'first_name' is already defined/)
    end
  end

  context "when the range has no end" do
    it "raises an exception" do
      expect {
        Class.new(described_class) do
          include Fixy::Formatter::Alphanumeric

          record_length 20
          field :first_name, 10, 1.., :alphanumeric
        end
      }.to raise_error(RangeError)
    end
  end

  context "when the range is not a range" do
    it "raises an exception" do
      expect {
        Class.new(described_class) do
          include Fixy::Formatter::Alphanumeric

          record_length 20
          field :first_name, 10, "nope", :alphanumeric
        end
      }.to raise_error(ArgumentError, "Range 'nope' is invalid")
    end
  end

  context "when the field name is not a symbol" do
    it "raises an exception" do
      expect {
        Class.new(described_class) do
          include Fixy::Formatter::Alphanumeric

          record_length 20
          field "first_name", 10, 1..10, :alphanumeric
        end
      }.to raise_error(ArgumentError, "Name 'first_name' is not a symbol")
    end
  end

  context "when the size is not a number" do
    it "raises an exception" do
      expect {
        Class.new(described_class) do
          include Fixy::Formatter::Alphanumeric

          record_length 20
          field :first_name, "10", 1..10, :alphanumeric
        end
      }.to raise_error(ArgumentError, "Size '10' is not a numeric")
    end
  end

  context "when the type is not known" do
    it "raises an exception" do
      expect {
        Class.new(described_class) do
          record_length 20
          field :first_name, 10, 1..10, :alphanumeric
        end
      }.to raise_error(ArgumentError, "Unknown type 'alphanumeric'")
    end
  end

  context "when the range is inconsistent with the size" do
    it "raises an exception" do
      expect {
        Class.new(described_class) do
          include Fixy::Formatter::Alphanumeric

          record_length 20
          field :first_name, 2, 1..10, :alphanumeric
        end
      }.to raise_error(ArgumentError, /Invalid Range/)
    end
  end

  context "when one range overlaps another" do
    it "raises an exception" do
      expect {
        Class.new(described_class) do
          include Fixy::Formatter::Alphanumeric

          record_length 20
          field :first_name, 10, 1..10, :alphanumeric
          field :last_name, 10, 10..19, :alphanumeric
        end
      }.to raise_error(ArgumentError, "Column 1 has already been allocated")
    end
  end

  context "when a range is outside its size definition" do
    it "raises an exception" do
      expect {
        Class.new(described_class) do
          include Fixy::Formatter::Alphanumeric

          record_length 10
          field :first_name, 10, 1..10, :alphanumeric
          field :last_name, 10, 11..20, :alphanumeric
        end
      }.to raise_error(ArgumentError, "Invalid Range (> 10)")
    end
  end

  describe "#generate" do
    context "when properly defined" do
      let(:person_record) do
        Class.new(Fixy::Record) do
          include Fixy::Formatter::Alphanumeric

          record_length 20

          field :first_name, 10, 1..10, :alphanumeric
          field :last_name, 10, 11..20, :alphanumeric

          field_value :first_name, -> { "Sarah" }

          def last_name
            "Kerrigan"
          end
        end
      end

      context "without the debug flag" do
        subject { person_record.new.generate }
        it { is_expected.to eq "Sarah     Kerrigan  \n" }
      end

      context "with the debug flag" do
        subject { person_record.new.generate(true) }

        it "produces a debug log" do
          is_expected.to eq File.read("spec/fixtures/debug_record.txt")
        end
      end
    end

    context "when dealing with multi-byte characters" do
      let(:person_record) do
        Class.new(Fixy::Record) do
          include Fixy::Formatter::Alphanumeric

          record_length 9

          field :name, 9, 1..9, :alphanumeric

          field_value :name, -> { "12345678И" }
        end
      end

      subject { person_record.new.generate }

      it { is_expected.to be_valid_encoding.and eq "12345678 \n" }
    end

    context "when a field value is a string" do
      subject { person_record.new.generate }
      let(:person_record) do
        Class.new(Fixy::Record) do
          include Fixy::Formatter::Alphanumeric

          record_length 9

          field :name, 9, 1..9, :alphanumeric

          field_value :name, "Sarah"
        end
      end

      it { is_expected.to eq "Sarah    \n" }
    end

    context "when a field value is nil" do
      let(:person_record) do
        Class.new(Fixy::Record) do
          include Fixy::Formatter::Alphanumeric

          record_length 9

          field :name, 9, 1..9, :alphanumeric

          field_value :name, -> {}
        end
      end

      subject { person_record.new.generate }

      it "emits spaces" do
        is_expected.to eq "         \n"
      end
    end

    context "when a field value contains the record separator" do
      let(:person_record) do
        Class.new(Fixy::Record) do
          include Fixy::Formatter::Alphanumeric

          record_length 9

          field :name, 9, 1..9, :alphanumeric

          field_value :name, -> { "Two\nLine" }
        end
      end

      subject { person_record.new.generate }

      it "strips that separator" do
        is_expected.to eq "TwoLine  \n"
      end
    end

    context "when definition is incomplete (e.g. undefined columns)" do
      let(:person_record) do
        Class.new(Fixy::Record) do
          include Fixy::Formatter::Alphanumeric

          record_length 20
          field :first_name, 10, 1..10, :alphanumeric
          field :last_name, 8, 11..18, :alphanumeric
          field_value :first_name, -> { "Sarah" }
          field_value :last_name, -> { "Kerrigan" }
        end
      end

      it "raises an error" do
        expect { person_record.new.generate }
          .to raise_error(StandardError, "Undefined field for position 19")
      end
    end

    context "when inheriting from another record" do
      let(:person_record_g) do
        Class.new(Fixy::Record) do
          include Fixy::Formatter::Alphanumeric

          record_length 20

          field :first_name, 10, 1..10, :alphanumeric
          field_value :first_name, -> { "Bob" }
        end
      end

      let(:person_record_h) do
        Class.new(person_record_g) do
          include Fixy::Formatter::Alphanumeric

          record_length 20
          field :last_name, 10, 11..20, :alphanumeric
          field_value :last_name, -> { "Williams" }
        end
      end

      it "includes fields from the superclass" do
        expect(person_record_h.new.generate.slice(0, 10)).to eq "Bob       "
        expect(person_record_h.new.generate.slice(10, 10)).to eq "Williams  "
      end

      context "when two records inherit" do
        let(:person_record_i) do
          Class.new(person_record_g) do
            include Fixy::Formatter::Alphanumeric

            record_length 20
            field :last_name, 10, 11..20, :alphanumeric
            field_value :last_name, -> { "Jacobs" }
          end
        end

        it "does not collide" do
          expect(person_record_h.new.generate.slice(0, 10)).to eq "Bob       "
          expect(person_record_h.new.generate.slice(10, 10)).to eq "Williams  "

          expect(person_record_i.new.generate.slice(0, 10)).to eq "Bob       "
          expect(person_record_i.new.generate.slice(10, 10)).to eq "Jacobs    "
        end
      end
    end

    context "when a block is passed to field" do
      let(:person_record) do
        Class.new(Fixy::Record) do
          include Fixy::Formatter::Alphanumeric

          record_length 20
          field(:description, 20, 1..20, :alphanumeric) { "Use My Value" }
        end
      end

      subject { person_record.new.generate }

      it "uses the proc conversion as the field value" do
        is_expected.to eq("Use My Value".ljust(20) << "\n")
      end
    end

    context "when setting a line ending" do
      let(:person_record) do
        Class.new(Fixy::Record) do
          include Fixy::Formatter::Alphanumeric

          record_length 20
          line_ending Fixy::Record::LINE_ENDING_CRLF
          field(:description, 20, 1..20, :alphanumeric) { "Use My Value" }
        end
      end

      subject { person_record.new.generate }

      it "uses the given line ending" do
        is_expected.to eq("Use My Value".ljust(20) << "\r\n")
      end
    end
  end

  describe "#parse" do
    let(:person_record) do
      Class.new(Fixy::Record) do
        include Fixy::Formatter::Alphanumeric

        record_length 20

        field :first_name, 10, 1..10, :alphanumeric
        field :last_name, 10, 11..20, :alphanumeric

        field_value :first_name, -> { "Sarah" }

        def last_name
          "Kerrigan"
        end
      end
    end

    context "with a record of multi-byte characters" do
      subject { person_record.parse(multibyte_record, true) }

      context "with the right number of bytes" do
        let(:multibyte_record) { "älimuk   Karil     " }

        it "does not raise an error with the right number of bytes" do
          is_expected.to eq(
            record: File.read("spec/fixtures/debug_parsed_multibyte_record.txt"),
            fields: [
              {name: :first_name, value: "älimuk   "},
              {name: :last_name, value: "Karil     "}
            ]
          )
        end
      end

      context "with the wrong number of bytes" do
        let(:multibyte_record) { "älimuk  Karil     " }

        it "raises an error with the wrong number of characters" do
          expect { subject }
            .to raise_error(StandardError, "Record length is invalid (Expected 20)")
        end
      end
    end

    context "with custom line endings" do
      let(:person_record) do
        Class.new(Fixy::Record) do
          include Fixy::Formatter::Alphanumeric

          record_length 20
          line_ending Fixy::Record::LINE_ENDING_CRLF
          field(:description, 20, 1..20, :alphanumeric) { "Use My Value" }
        end
      end
      let(:record) { "Use My Value        " }
      subject { person_record.parse(record) }

      it "generates a fixed width record" do
        is_expected.to eq(
          record: (record + Fixy::Record::LINE_ENDING_CRLF),
          fields: [{name: :description, value: "Use My Value        "}]
        )
      end
    end

    context "when properly defined" do
      let(:record) { "Sarah     Kerrigan  " }
      let(:person_record) do
        Class.new(Fixy::Record) do
          include Fixy::Formatter::Alphanumeric

          record_length 20

          field :first_name, 10, 1..10, :alphanumeric
          field :last_name, 10, 11..20, :alphanumeric

          field_value :first_name, -> { "Sarah" }

          def last_name
            "Kerrigan"
          end
        end
      end

      it "generates a fixed width record" do
        expect(person_record.parse(record)).to eq(
          record: (record + "\n"),
          fields: [
            {name: :first_name, value: "Sarah     "},
            {name: :last_name, value: "Kerrigan  "}
          ]
        )
      end

      context "when using the debug flag" do
        it "produces a debug log" do
          expect(person_record.parse(record, true)).to eq(
            record: File.read("spec/fixtures/debug_parsed_record.txt"),
            fields: [
              {name: :first_name, value: "Sarah     "},
              {name: :last_name, value: "Kerrigan  "}
            ]
          )
        end
      end

      context "when invalid record provided" do
        context "with a non-string record type" do
          it "raises an error" do
            expect { person_record.parse(nil, true) }
              .to raise_error(StandardError, "Record must be a string")
          end
        end

        context "with an invalid record length" do
          it "raises an error" do
            expect { person_record.parse("", true) }
              .to raise_error(StandardError, "Record length is invalid (Expected 20)")
          end
        end
      end
    end

    context "when definition is incomplete (e.g. undefined columns)" do
      let(:person_record) do
        Class.new(Fixy::Record) do
          include Fixy::Formatter::Alphanumeric

          record_length 20
          field :first_name, 10, 1..10, :alphanumeric
          field :last_name, 8, 11..18, :alphanumeric
          field_value :first_name, -> { "Sarah" }
          field_value :last_name, -> { "Kerrigan" }
        end
      end

      subject { person_record.parse(" " * 20) }

      it "raises an error" do
        expect { subject }
          .to raise_error(StandardError, "Undefined field for position 19")
      end
    end
  end
end
