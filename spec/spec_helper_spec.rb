require 'spec_helper'

RSpec.describe SibSpecHelpers::Version do
  let(:v231) { SibSpecHelpers::Version.new '2.3.1' }
  example { expect(v231).to eq v231 }
  example { expect(v231).to eq '2.3.1' }
  example { expect(v231).to_not be < '2' }
  example { expect(v231).to     be < '3' }
  example { expect(v231).to_not be < '2.2' }
  example { expect(v231).to_not be < '2.3' }
  example { expect(v231).to     be < '2.4' }
  example { expect(v231).to_not be < '2.3.0' }
  example { expect(v231).to_not be < '2.3.1' }
  example { expect(v231).to     be < '2.3.2' }
  example { expect(v231).to     be < '2.3.1.0' }
end
