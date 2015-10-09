require 'spec_helper'

class SluggingSpec < Minitest::Spec
  include Minitest::Hooks

  class Widget < Sequel::Model
    def method_returning_nil
      nil
    end

    def method_returning_empty_string
      ''
    end

    def method_returning_false
      false
    end

    def method_returning_object
      Object.new
    end
  end

  def assert_slug(slug, model)
    in_model = model.slug
    in_db    = model.this.get(:slug)

    case slug
    when String
      assert_equal slug, in_model
      assert_equal slug, in_db
    when Regexp
      assert_match slug, in_model
      assert_match slug, in_db
    else
      raise "Bad slug!: #{slug.inspect}"
    end
  end

  before do
    Widget.plugin :slugging, source: :name
  end

  around do |&block|
    DB.transaction(rollback: :always, savepoint: true, auto_savepoint: true) do
      super(&block)
    end
  end

  it "should have a version number" do
    assert_instance_of String, ::Sequel::Plugins::Slugging::VERSION
    assert ::Sequel::Plugins::Slugging::VERSION.frozen?
  end

  it "should have the slugging opts available on the model" do
    assert_equal Widget.slugging_opts, {source: :name}
    assert Widget.slugging_opts.frozen?
  end

  it "should support replacing slugging opts without issue" do
    Widget.plugin :slugging, source: :other
    assert_equal Widget.slugging_opts, {source: :other}
    assert Widget.slugging_opts.frozen?
  end

  it "should inherit slugging opts appropriately when subclassed" do
    class WidgetSubclass < Widget
    end

    assert_equal Widget.slugging_opts, {source: :name}
    assert Widget.slugging_opts.frozen?

    assert_equal WidgetSubclass.slugging_opts, {source: :name}
    assert WidgetSubclass.slugging_opts.frozen?
  end

  it "should support alternate logic for slugifying strings" do
    begin
      Sequel::Plugins::Slugging.slugifier = proc(&:upcase)
      assert_slug 'BLAH', Widget.create(name: "blah")
    ensure
      Sequel::Plugins::Slugging.slugifier = nil
    end
  end

  it "should support a universal list of reserved words that shouldn't be slugs" do
    begin
      Sequel::Plugins::Slugging.reserved_words = ['blah', 'hello']
      assert_slug(/\Ablah-[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}\z/, Widget.create(name: "blah"))
    ensure
      Sequel::Plugins::Slugging.reserved_words = nil
    end
  end

  describe "when finding a record by a slug or id" do
    describe "when the id is an integer type" do
      it "should successfully look up records by their slug" do
        widget = Widget.create name: "Blah"
        assert_equal widget.id, Widget.from_slug('blah').id
        assert_equal widget.id, Widget.from_slug!('blah').id
      end

      it "should successfully look up records by their id" do
        widget = Widget.create name: "Blah"
        assert_equal widget.id, Widget.from_slug(widget.id).id
        assert_equal widget.id, Widget.from_slug!(widget.id).id
        assert_equal widget.id, Widget.from_slug(widget.id.to_s).id
        assert_equal widget.id, Widget.from_slug!(widget.id.to_s).id
      end

      it "should respond appropriately when the slug or id doesn't exist" do
        widget = Widget.create name: "Blah"
        assert_nil Widget.from_slug('gsnrosehe')
        assert_nil Widget.from_slug(widget.id + 1)
        assert_raises(Sequel::NoMatchingRow){Widget.from_slug!('gsnrosehe')}
        assert_raises(Sequel::NoMatchingRow){Widget.from_slug!(widget.id + 1)}
      end
    end

    describe "when the id is a uuid type" do
      before do
        DB.drop_table :widgets
        DB.create_table :widgets do
          uuid :id, primary_key: true, default: Sequel.function(:uuid_generate_v4)

          text :name, null: false
          text :slug, null: false, unique: true
        end

        @original_db_schema = Widget.db_schema
        Widget.send(:instance_variable_set, :@db_schema, nil)
      end

      after do
        Widget.send(:instance_variable_set, :@db_schema, @original_db_schema)
      end

      it "should successfully look up records by their slug" do
        widget = Widget.create name: "Blah"
        assert_equal widget.id, Widget.from_slug('blah').id
        assert_equal widget.id, Widget.from_slug!('blah').id
      end

      it "should successfully look up records by their id" do
        widget = Widget.create name: "Blah"
        assert_equal widget.id, Widget.from_slug(widget.id).id
        assert_equal widget.id, Widget.from_slug!(widget.id).id
      end

      it "should respond appropriately when the slug or id isn't found" do
        widget = Widget.create name: "Blah"
        assert_nil Widget.from_slug('gsnrosehe')
        assert_raises(Sequel::NoMatchingRow){Widget.from_slug!('gsnrosehe')}
      end
    end
  end

  describe "when calculating a slug" do
    it "should prevent duplicates" do
      assert_slug 'blah', Widget.create(name: "Blah")
      assert_slug(/\Ablah-[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}\z/, Widget.create(name: "Blah"))
    end

    it "should enforce a maximum length" do
      begin
        assert_equal Sequel::Plugins::Slugging.maximum_length, 50
        Sequel::Plugins::Slugging.maximum_length = 10

        string = "Turn around, bright eyes! Every now and then I fall apart!"

        first  = Widget.create(name: string)
        second = Widget.create(name: string)

        assert_slug 'turn-aroun', first
        assert_slug(/\Aturn-aroun-[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}\z/, second)
      ensure
        Sequel::Plugins::Slugging.maximum_length = 50
      end
    end

    it "should support logic to normalize slug input"

    it "should support logic to determine when to calculate a new slug"

    describe "from a source method" do
      it "should simplify the returned text by default" do
        names = [
          "Tra la la", # Standard
          "Tra la la!", # With non-alphanumeric
          "Tra  la  la", # With excess whitespace
          "  Tra la la  !  ", # With whitespace at beginning and end
          "345 Tra la la!!!", # With numerics that could confuse a search for an id = 345
          "Tra la 735 la!", # More numerics
        ]

        names.each do |name|
          widget = Widget.create name: name
          assert_slug 'tra-la-la', widget
          widget.destroy # Avoid uniqueness issues.
        end
      end

      it "should behave sensibly when a source returns nil" do
        Widget.plugin :slugging, source: :method_returning_nil
        assert_slug(/\A[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}\z/, Widget.create(name: 'Blah'))
      end

      it "should behave sensibly when a source returns an empty string" do
        Widget.plugin :slugging, source: :method_returning_empty_string
        assert_slug(/\A[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}\z/, Widget.create(name: 'Blah'))
      end

      it "should behave sensibly when there's no source" do
        Widget.plugin :slugging, source: nil
        assert_slug(/\A[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}\z/, Widget.create(name: 'blah'))
      end

      describe "from a collection of string source methods" do
        def new_widget
          Widget.create(name: "name", other_text: "other text", more_text: "more text")
        end

        it "should use the source method collection to determine a slug" do
          Widget.plugin :slugging, source: [:name, [:name, :other_text], [:name, :more_text], [:name, :other_text, :more_text]]

          assert_slug 'name', new_widget
          assert_slug 'name-other-text', new_widget
          assert_slug 'name-more-text', new_widget
          assert_slug 'name-other-text-more-text', new_widget
          assert_slug(/\Aname-[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}\z/, new_widget)
        end

        it "should be resilient to sources that return nil" do
          Widget.plugin :slugging, source: [:method_returning_nil, :name, [:name, :other_text]]

          assert_slug 'name', new_widget
          assert_slug 'name-other-text', new_widget
          assert_slug(/\Aname-[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}\z/, new_widget)
        end

        it "should raise an error if a source returns something unexpected" do
          Widget.plugin :slugging, source: [:method_returning_object, :name]
          assert_raises(Sequel::Plugins::Slugging::Error) { new_widget }

          Widget.plugin :slugging, source: [:method_returning_false, :name]
          assert_raises(Sequel::Plugins::Slugging::Error) { new_widget }
        end

        it "should be resilient to sources that return empty strings" do
          Widget.plugin :slugging, source: [:method_returning_empty_string, :name, [:name, :other_text]]

          assert_slug 'name', new_widget
          assert_slug 'name-other-text', new_widget
          assert_slug(/\Aname-[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}\z/, new_widget)
        end

        it "should behave sensibly when no sources are good" do
          Widget.plugin :slugging, source: [:method_returning_empty_string, :method_returning_nil]
          assert_slug(/\A[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}\z/, new_widget)

          Widget.plugin :slugging, source: [:method_returning_nil, :method_returning_empty_string]
          assert_slug(/\A[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}\z/, new_widget)
        end
      end
    end

    describe "when given the history option" do
      it "should avoid slugs that have been used before"

      it "should save new slugs to the history table as they are assigned"

      it "should look up slugs from that table when querying by slug"
    end
  end
end
