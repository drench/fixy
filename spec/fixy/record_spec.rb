describe Fixy::Record do
  context "when the definition is correct" do
    it "raises no exception" do
      expect {
        Class.new(described_class) do
          include Fixy::Formatter::Alphanumeric

          set_record_length 20

          set_line_ending Fixy::Record::LINE_ENDING_CRLF

          field :first_name, 10, "1-10", :alphanumeric
          field :last_name, 10, "11-20", :alphanumeric
        end
      }.not_to raise_error
    end
  end

  context "when the definition is incorrect" do
    it "raises an appropriate exception" do
      expect {
        Class.new(described_class) do
          include Fixy::Formatter::Alphanumeric

          set_record_length 20
          field_value :first_name, -> { "Sarah" }
          field_value :first_name, -> { "Sarah" }
        end
      }.to raise_error(ArgumentError, /Method 'first_name' is already defined/)

      expect {
        Class.new(described_class) do
          include Fixy::Formatter::Alphanumeric

          set_record_length 20
          field :first_name, 10, "1", :alphanumeric
        end
      }.to raise_error(ArgumentError, "Invalid Range (size: 10, range: 1)")

      expect {
        Class.new(described_class) do
          include Fixy::Formatter::Alphanumeric

          set_record_length 20
          field :first_name, 10, "nope", :alphanumeric
        end
      }.to raise_error(ArgumentError, "Range 'nope' is invalid")

      expect {
        Class.new(described_class) do
          include Fixy::Formatter::Alphanumeric

          set_record_length 20
          field "first_name", 10, "1-10", :alphanumeric
        end
      }.to raise_error(ArgumentError, "Name 'first_name' is not a symbol")

      expect {
        Class.new(described_class) do
          include Fixy::Formatter::Alphanumeric

          set_record_length 20
          field :first_name, "10", "1-10", :alphanumeric
        end
      }.to raise_error(ArgumentError, "Size '10' is not a numeric")

      expect {
        Class.new(described_class) do
          set_record_length 20
          field :first_name, 10, "1-10", :alphanumeric
        end
      }.to raise_error(ArgumentError, "Unknown type 'alphanumeric'")

      expect {
        Class.new(described_class) do
          include Fixy::Formatter::Alphanumeric

          set_record_length 20
          field :first_name, 2, "1-10", :alphanumeric
        end
      }.to raise_error(ArgumentError, "Invalid Range (size: 2, range: 1-10)")

      expect {
        Class.new(described_class) do
          include Fixy::Formatter::Alphanumeric

          set_record_length 20
          field :first_name, 10, "1-10", :alphanumeric
          field :last_name, 10, "10-19", :alphanumeric
        end
      }.to raise_error(ArgumentError, "Column 1 has already been allocated")

      expect {
        Class.new(described_class) do
          include Fixy::Formatter::Alphanumeric

          set_record_length 10
          field :first_name, 10, "1-10", :alphanumeric
          field :last_name, 10, "11-20", :alphanumeric
        end
      }.to raise_error(ArgumentError, "Invalid Range (> 10)")
    end
  end
end

describe "Generating a Record" do
  context "when properly defined" do
    let(:person_record_e) do
      Class.new(Fixy::Record) do
        include Fixy::Formatter::Alphanumeric

        set_record_length 20

        field :first_name, 10, "1-10", :alphanumeric
        field :last_name, 10, "11-20", :alphanumeric

        field_value :first_name, -> { "Sarah" }

        def last_name
          "Kerrigan"
        end
      end
    end

    it "generates a fixed width record" do
      expect(person_record_e.new.generate).to eq "Sarah     Kerrigan  \n"
    end

    context "when using the debug flag" do
      it "produces a debug log" do
        expect(person_record_e.new.generate(true))
          .to eq File.read("spec/fixtures/debug_record.txt")
      end
    end
  end

  context "when dealing with multi-byte characters" do
    let(:person_record_multibyte) do
      Class.new(Fixy::Record) do
        include Fixy::Formatter::Alphanumeric

        set_record_length 9

        field :name, 9, "1-9", :alphanumeric

        field_value :name, -> { "12345678И" }
      end
    end

    it "generates a fixed width record" do
      value = person_record_multibyte.new.generate
      expect(value).to be_valid_encoding
      expect(value).to eq "12345678 \n"
    end
  end

  context "when a field value is a string" do
    subject { person_record.new.generate }
    let(:person_record) do
      Class.new(Fixy::Record) do
        include Fixy::Formatter::Alphanumeric

        set_record_length 9

        field :name, 9, "1-9", :alphanumeric

        field_value :name, "Sarah"
      end
    end

    it { is_expected.to eq "Sarah    \n" }
  end

  context "when a field value is nil" do
    let(:person_record_nil) do
      Class.new(Fixy::Record) do
        include Fixy::Formatter::Alphanumeric

        set_record_length 9

        field :name, 9, "1-9", :alphanumeric

        field_value :name, -> {}
      end
    end

    it "emits spaces" do
      value = person_record_nil.new.generate
      expect(value).to eq "         \n"
    end
  end

  context "when a field value contains the record separator" do
    let(:person_record_new_line) do
      Class.new(Fixy::Record) do
        include Fixy::Formatter::Alphanumeric

        set_record_length 9

        field :name, 9, "1-9", :alphanumeric

        field_value :name, -> { "Two\nLine" }
      end
    end

    it "strips that separator" do
      value = person_record_new_line.new.generate
      expect(value).to eq "TwoLine  \n"
    end
  end

  context "when definition is incomplete (e.g. undefined columns)" do
    let(:person_record_f) do
      Class.new(Fixy::Record) do
        include Fixy::Formatter::Alphanumeric

        set_record_length 20
        field :first_name, 10, "1-10", :alphanumeric
        field :last_name, 8, "11-18", :alphanumeric
        field_value :first_name, -> { "Sarah" }
        field_value :last_name, -> { "Kerrigan" }
      end
    end

    it "raises an error" do
      expect { person_record_f.new.generate }
        .to raise_error(StandardError, "Undefined field for position 19")
    end
  end

  context "when inheriting from another record" do
    let(:person_record_g) do
      Class.new(Fixy::Record) do
        include Fixy::Formatter::Alphanumeric

        set_record_length 20

        field :first_name, 10, "1-10", :alphanumeric
        field_value :first_name, -> { "Bob" }
      end
    end

    let(:person_record_h) do
      Class.new(person_record_g) do
        include Fixy::Formatter::Alphanumeric

        set_record_length 20
        field :last_name, 10, "11-20", :alphanumeric
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

          set_record_length 20
          field :last_name, 10, "11-20", :alphanumeric
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
    let(:person_record_j) do
      Class.new(Fixy::Record) do
        include Fixy::Formatter::Alphanumeric

        set_record_length 20
        field(:description, 20, "1-20", :alphanumeric) { "Use My Value" }
      end
    end

    it "uses the proc conversion as the field value" do
      expect(person_record_j.new.generate).to eq("Use My Value".ljust(20) << "\n")
    end
  end

  context "when setting a line ending" do
    let(:person_record_with_line_ending) do
      Class.new(Fixy::Record) do
        include Fixy::Formatter::Alphanumeric

        set_record_length 20
        set_line_ending Fixy::Record::LINE_ENDING_CRLF
        field(:description, 20, "1-20", :alphanumeric) { "Use My Value" }
      end
    end

    it "uses the given line ending" do
      expect(person_record_with_line_ending.new.generate)
        .to eq("Use My Value".ljust(20) << "\r\n")
    end
  end
end

describe "Parsing a record" do
  let(:multibyte_record) { "älimuk   Karil     " }
  let(:person_record_e) do
    Class.new(Fixy::Record) do
      include Fixy::Formatter::Alphanumeric

      set_record_length 20

      field :first_name, 10, "1-10", :alphanumeric
      field :last_name, 10, "11-20", :alphanumeric

      field_value :first_name, -> { "Sarah" }

      def last_name
        "Kerrigan"
      end
    end
  end

  context "with a record of multi-byte characters" do
    it "does not raise an error with the right number of bytes" do
      expect(person_record_e.parse(multibyte_record, true)).to eq(
        record: File.read("spec/fixtures/debug_parsed_multibyte_record.txt"),
        fields: [
          {name: :first_name, value: "älimuk   "},
          {name: :last_name, value: "Karil     "}
        ]
      )
    end

    it "raises an error with the wrong number of characters" do
      expect { person_record_e.parse("älimuk  Karil     ", true) }
        .to raise_error(StandardError, "Record length is invalid (Expected 20)")
    end
  end

  context "with custom line endings" do
    let(:person_record_with_line_ending) do
      Class.new(Fixy::Record) do
        include Fixy::Formatter::Alphanumeric

        set_record_length 20
        set_line_ending Fixy::Record::LINE_ENDING_CRLF
        field(:description, 20, "1-20", :alphanumeric) { "Use My Value" }
      end
    end
    let(:record) { "Use My Value        " }

    it "generates a fixed width record" do
      expect(person_record_with_line_ending.parse(record)).to eq(
        record: (record + Fixy::Record::LINE_ENDING_CRLF),
        fields: [{name: :description, value: "Use My Value        "}]
      )
    end
  end

  context "when properly defined" do
    let(:record) { "Sarah     Kerrigan  " }
    let(:person_record_k) do
      Class.new(Fixy::Record) do
        include Fixy::Formatter::Alphanumeric

        set_record_length 20

        field :first_name, 10, "1-10", :alphanumeric
        field :last_name, 10, "11-20", :alphanumeric

        field_value :first_name, -> { "Sarah" }

        def last_name
          "Kerrigan"
        end
      end
    end

    it "generates a fixed width record" do
      expect(person_record_e.parse(record)).to eq(
        record: (record + "\n"),
        fields: [
          {name: :first_name, value: "Sarah     "},
          {name: :last_name, value: "Kerrigan  "}
        ]
      )
    end

    context "when using the debug flag" do
      it "produces a debug log" do
        expect(person_record_e.parse(record, true)).to eq(
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
          expect { person_record_e.parse(nil, true) }
            .to raise_error(StandardError, "Record must be a string")
        end
      end

      context "with an invalid record length" do
        it "raises an error" do
          expect { person_record_e.parse("", true) }
            .to raise_error(StandardError, "Record length is invalid (Expected 20)")
        end
      end
    end
  end

  context "when definition is incomplete (e.g. undefined columns)" do
    let(:person_record_l) do
      Class.new(Fixy::Record) do
        include Fixy::Formatter::Alphanumeric

        set_record_length 20
        field :first_name, 10, "1-10", :alphanumeric
        field :last_name, 8, "11-18", :alphanumeric
        field_value :first_name, -> { "Sarah" }
        field_value :last_name, -> { "Kerrigan" }
      end
    end

    it "raises an error" do
      expect { person_record_l.parse(" " * 20) }
        .to raise_error(StandardError, "Undefined field for position 19")
    end
  end
end
