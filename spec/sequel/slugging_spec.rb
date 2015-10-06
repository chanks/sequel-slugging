require 'spec_helper'

class SluggingSpec < Minitest::Spec
  class Widget < Sequel::Model
  end

  before do
    Widget.plugin :slugging, source: :name
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

  it "should support alternate logic for slugifying strings"

  it "should support a dataset method to find a record by slug or id"

  it "should support a universal list of reserved words that shouldn't be slugs"

  describe "when calculating a slug" do
    it "should use the source method to determine a slug" do
      ["Tra la la", "Tra la la!", "Tra  la  la", "  Tra la la  !  "].each do |input|
        widget = Widget.create name: input
        assert_equal 'tra-la-la', widget.slug
        widget.destroy # Avoid uniqueness issues.
      end
    end

    it "should prevent duplicate slugs" do
      Widget.create name: "Blah"
      Widget.create name: "Blah"

      first, second = Widget.select_order_map(:slug)
      assert_equal 'blah', first
      assert_match(/\Ablah-[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}\z/, second)
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
