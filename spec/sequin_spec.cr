require "spec"
require "../src/sequin"

describe Block do
  describe "#new" do
    it "correctly generates a hash" do
      block = Block.new("2021/02/13", { "amount" => 10 })
      block.block_hash.should be_a(String)
    end
  end
end
