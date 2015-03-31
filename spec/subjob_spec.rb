require 'spec_helper'

describe Sidekiq::Superworker::Subjob do
  before :each do
    Sidekiq.redis { |conn| conn.flushdb }
  end

  let(:attributes) do
    {
      :subjob_id => "456",
      :superjob_id => "8910",
      :parent_id => "1",
      :children_ids => ["3"],
      :next_id => 3,
      :subworker_class => "Subworker",
      :superworker_class => "Superworker",
      :arg_keys => [:a, :b],
      :arg_values => [:c, :d],
      :status => "queued",
      :descendants_are_complete => false,
      :meta => nil
    }
  end

  def create_subjob(custom_attributes={})
    described_class.create(attributes.merge(custom_attributes))
  end

  describe '.create' do
    it 'creates a subjob' do
      described_class.create(attributes).should be_a(described_class)
    end

    context 'with an array argument' do
      it 'creates subjobs' do
        array = [attributes] * 2
        subjobs = described_class.create(array)
        subjobs.length.should == 2
        subjobs[0].should be_a(described_class)
        subjobs[1].should be_a(described_class)
      end      
    end
  end

  describe '.find_by_jid' do
    it 'finds a subjob' do
      subjob = described_class.create(attributes)
      described_class.find_by_jid(subjob.jid).should be_a(described_class)
    end
  end

  describe '.find_by_superjob_jid' do
    it 'finds the superjobs\'s subjobs' do
      superjob_jid = SimpleSuperworker.perform_async(10, 11)
      subjobs = described_class.find_by_superjob_jid(superjob_jid)
      subjobs.map(&:subworker_class).should =~ %w{Worker1 Worker2}
    end
  end

  describe '.all' do
    it 'returns all subjobs' do
      subjobs = 3.times.map { |i| create_subjob({ subjob_id: i }) }
      described_class.all.should =~ subjobs
    end
  end

  describe '.count' do
    it 'returns the count of all subjobs' do
      subjobs = 3.times.map { |i| create_subjob({ subjob_id: i }) }
      described_class.count.should == 3

    end
  end

  describe '#save' do
    it 'creates a hashmap in redis' do
      subjob = described_class.new(attributes)
      subjob.save
      Sidekiq.redis do |conn|
        expect(conn.hkeys(subjob.key)).to eq(subjob.to_param.keys.map(&:to_s))
      end
    end

    context 'superjob_expiration is set' do
      it "sets the subjobs expiry accordingly" do
        allow(Sidekiq::Superworker).to receive("options") {{subjob_redis_prefix: 'subjob',  superjob_expiration: 123}}

        subjob = described_class.new(attributes)
        subjob.save
        Sidekiq.redis do |conn|
          expect(conn.ttl(subjob.key)).to be 123
        end
      end
    end

    context 'superjob_expiration is not set' do
      it "sets the subjobs expiry accordingly" do
        subjob = described_class.new(attributes)
        subjob.save
        Sidekiq.redis do |conn|
          expect(conn.ttl(subjob.key)).to be -1
        end
      end
    end
  end

  describe '#to_param' do
    it 'returns a hash including all given attributes' do
      subjob = described_class.new(attributes)
      subjob.to_param.should eq(attributes.each { |key, value| attributes[key] = value.to_json })
    end
  end
end
