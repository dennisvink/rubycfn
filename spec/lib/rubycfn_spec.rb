require "spec_helper"

require "rubycfn"
require "active_support/concern"

describe Rubycfn do

  module RSpec
    include Rubycfn
  end

  context "renders template" do
    let(:template) { JSON.parse(RSpec.render_template) }
    subject { template }

    it { should_not have_key 'Parameters' }
    it { should_not have_key 'Outputs' }
    it { should have_key 'Resources' }
  end
end
