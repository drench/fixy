describe Fixy::Document do
  context "when a build action is not defined" do
    it "raises an exception" do
      expect { subject.generate }.to raise_error(NotImplementedError)
    end
  end

  context "when a build action is defined" do
    let(:identity_record) do
      Class.new(Fixy::Record) do
        set_record_length 20
        include Fixy::Formatter::Alphanumeric

        field :first_name, 10, 1..10, :alphanumeric
        field :last_name, 10, 11..20, :alphanumeric

        def initialize(first_name, last_name)
          @first_name = first_name
          @last_name = last_name
        end

        field_value :first_name, -> { @first_name }
        field_value :last_name, -> { @last_name }
      end
    end

    let(:people_document) do
      records = [
        identity_record.new("Sarah", "Kerrigan"),
        identity_record.new("Jim", "Raynor"),
        identity_record.new("Arcturus", "Mengsk")
      ]

      Class.new(described_class).tap do |klass|
        klass.define_method(:build) do
          append_record records[0]
          append_record records[1]
          prepend_record records[2]
        end
      end
    end

    let(:parsed_people_document) do
      record = identity_record

      Class.new(described_class).tap do |klass|
        klass.define_method(:build) do
          parse_record record, "Arcturus  Mengsk    "
          parse_record record, "Sarah     Kerrigan  "
          parse_record record, "Jim       Raynor    "
        end
      end
    end

    it "generates a fixed width document" do
      expect(people_document.new.generate)
        .to eq "Arcturus  Mengsk    \nSarah     Kerrigan  \nJim       Raynor    \n"
      expect(people_document.new.generate(true))
        .to eq File.read("spec/fixtures/debug_document.txt")
    end

    it "parses a fixed width document" do
      expect(parsed_people_document.new.generate)
        .to eq "Arcturus  Mengsk    \nSarah     Kerrigan  \nJim       Raynor    \n"
      expect(parsed_people_document.new.generate(true))
        .to eq File.read("spec/fixtures/debug_document.txt")
    end
  end
end
