require 'spec_helper'

class SluggingSpec < Minitest::Spec
  include Minitest::Hooks

  class Widget < Sequel::Model
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
      it "should successfully look up records by their slug"

      it "should successfully look up records by their id"

      it "should not pass the slug to the DB when it isn't formatted like an integer"
    end

    describe "when the id is a uuid type" do
      it "should successfully look up records by their slug"

      it "should successfully look up records by their id"

      it "should not pass the id to the DB when it isn't formatted like a uuid"
    end
  end

  describe "when calculating a slug" do
    it "should use the source method to determine a slug" do
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

    it "should prevent duplicate slugs" do
      first  = Widget.create name: "Blah"
      second = Widget.create name: "Blah"

      assert_slug 'blah', first
      assert_slug(/\Ablah-[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}\z/, second)
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

    describe "from a collection of string source methods" do
      it "should use the source method to determine a slug"

      it "should avoid duplicate slugs"
    end

    describe "when given the history option" do
      it "should avoid slugs that have been used before"

      it "should save new slugs to the history table as they are assigned"

      it "should look up slugs from that table when querying by slug"
    end
  end
end
