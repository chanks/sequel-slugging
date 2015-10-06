require 'spec_helper'

class SluggingSpec < Minitest::Spec
  class Widget < Sequel::Model
    plugin :slugging, source: :name
  end

  it "should have a version number" do
    assert_instance_of String, ::Sequel::Plugins::Slugging::VERSION
  end

  it "should have the slugging opts available on the model" do
    assert_equal Widget.slugging_opts, {source: :name}
    assert Widget.slugging_opts.frozen?
  end

  it "should support a dataset method to find a record by slug or id"

  it "should inherit slugging opts appropriately when subclassed"

  it "should support a universal list of reserved words that shouldn't be slugs"

  describe "when calculating a slug" do
    describe "from a single method returning a string" do
      it "should use the source method to determine a slug"

      it "should avoid duplicate slugs"

      it "should support logic to normalize slug input"

      it "should support logic to determine when to calculate a new slug"
    end

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
