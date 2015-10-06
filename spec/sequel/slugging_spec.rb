require 'spec_helper'

class SluggingSpec < Minitest::Spec
  it "should have a version number" do
    assert_instance_of String, ::Sequel::Plugins::Slugging::VERSION
  end
end
