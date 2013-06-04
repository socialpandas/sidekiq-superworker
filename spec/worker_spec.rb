require 'spec_helper'

# TODO: Write simpler tests!

describe Sidekiq::Superworker::Worker do
  queue_name = 'sidekiq_superworker_test'

  before :all do
    @queue = Sidekiq::Queue.new(queue_name)
    clean_datastores

    # For testing complex dependencies
    Sidekiq::Superworker::Worker.create(:ComplexSuperworker, :first_argument, :second_argument) do
      Worker1 :first_argument do       # 1
        Worker2 :second_argument       # 2
        Worker3 :second_argument do    # 3
          Worker4 :first_argument      # 4
          parallel do                  # 5
            Worker5 :first_argument    # 6
            Worker6 :first_argument do # 7
              Worker7 :first_argument  # 8
              Worker8 :first_argument  # 9
            end
          end
        end
        Worker9 :first_argument        # 10
      end
    end

    # For testing that empty arguments work
    Sidekiq::Superworker::Worker.create(:EmptyArgumentsSuperworker) do
      Worker1 do
        Worker2()
      end
    end

    # For testing that nested superworkers work
    Sidekiq::Superworker::Worker.create(:ChildSuperworker) do
      Worker2 do
        Worker3()
      end
    end
    Sidekiq::Superworker::Worker.create(:NestedSuperworker) do
      Worker1()
      ChildSuperworker()
    end
  end

  describe '.perform_async' do
    context 'empty arguments superworker' do
      before :all do
        worker_perform_async(EmptyArgumentsSuperworker)
      end

      after :all do
        clean_datastores
      end

      it 'creates the correct Subjob records' do
        expected_record_hashes = {
         1=>
          {:subjob_id=>1,
           :parent_id=>nil,
           :children_ids=>[2],
           :next_id=>nil,
           :subworker_class=>"Worker1",
           :superworker_class=>"EmptyArgumentsSuperworker",
           :arg_keys=>[],
           :arg_values=>[],
           :status=>"queued",
           :descendants_are_complete=>false},
         2=>
          {:subjob_id=>2,
           :parent_id=>1,
           :children_ids=>nil,
           :next_id=>nil,
           :subworker_class=>"Worker2",
           :superworker_class=>"EmptyArgumentsSuperworker",
           :arg_keys=>[],
           :arg_values=>[],
           :status=>"initialized",
           :descendants_are_complete=>false}
        }

        record_hashes = subjobs_to_indexed_hash(Sidekiq::Superworker::Subjob.all)

        record_hashes.should have(expected_record_hashes.length).items
        record_hashes.each do |subjob_id, record_hash|
          expected_record_hashes[subjob_id].should == record_hash
        end
      end
    end

    context 'nested superworker' do
      before :all do
        worker_perform_async(NestedSuperworker)
      end

      after :all do
        clean_datastores
      end

      it 'creates the correct Subjob records' do
        expected_record_hashes = {
          1=>
            {:subjob_id=>1,
             :parent_id=>nil,
             :children_ids=>nil,
             :next_id=>2,
             :subworker_class=>"Worker1",
             :superworker_class=>"NestedSuperworker",
             :arg_keys=>[],
             :arg_values=>[],
             :status=>"queued",
             :descendants_are_complete=>false},
          2=>
            {:subjob_id=>2,
             :parent_id=>nil,
             :children_ids=>[3],
             :next_id=>nil,
             :subworker_class=>"ChildSuperworker",
             :superworker_class=>"NestedSuperworker",
             :arg_keys=>[],
             :arg_values=>[],
             :status=>"initialized",
             :descendants_are_complete=>false},
          3=>
            {:subjob_id=>3,
             :parent_id=>2,
             :children_ids=>[4],
             :next_id=>nil,
             :subworker_class=>"Worker2",
             :superworker_class=>"NestedSuperworker",
             :arg_keys=>[],
             :arg_values=>[],
             :status=>"initialized",
             :descendants_are_complete=>false},
          4=>
            {:subjob_id=>4,
             :parent_id=>3,
             :children_ids=>nil,
             :next_id=>nil,
             :subworker_class=>"Worker3",
             :superworker_class=>"NestedSuperworker",
             :arg_keys=>[],
             :arg_values=>[],
             :status=>"initialized",
             :descendants_are_complete=>false}
        }

        record_hashes = subjobs_to_indexed_hash(Sidekiq::Superworker::Subjob.all)

        record_hashes.should have(expected_record_hashes.length).items
        record_hashes.each do |subjob_id, record_hash|
          expected_record_hashes[subjob_id].should == record_hash
        end
      end
    end

    context 'complex superworker' do
      before :all do
        worker_perform_async(ComplexSuperworker)
      end
      
      after :all do
        clean_datastores
      end

      it 'creates the correct Subjob records' do
        expected_record_hashes = {
         1=>
          {:subjob_id=>1,
           :parent_id=>nil,
           :children_ids=>[2, 3, 10],
           :next_id=>nil,
           :subworker_class=>"Worker1",
           :superworker_class=>"ComplexSuperworker",
           :arg_keys=>[:first_argument],
           :arg_values=>[100],
           :status=>"queued",
           :descendants_are_complete=>false},
         2=>
          {:subjob_id=>2,
           :parent_id=>1,
           :children_ids=>nil,
           :next_id=>3,
           :subworker_class=>"Worker2",
           :superworker_class=>"ComplexSuperworker",
           :arg_keys=>[:second_argument],
           :arg_values=>[101],
           :status=>"initialized",
           :descendants_are_complete=>false},
         3=>
          {:subjob_id=>3,
           :parent_id=>1,
           :children_ids=>[4, 5],
           :next_id=>10,
           :subworker_class=>"Worker3",
           :superworker_class=>"ComplexSuperworker",
           :arg_keys=>[:second_argument],
           :arg_values=>[101],
           :status=>"initialized",
           :descendants_are_complete=>false},
         4=>
          {:subjob_id=>4,
           :parent_id=>3,
           :children_ids=>nil,
           :next_id=>5,
           :subworker_class=>"Worker4",
           :superworker_class=>"ComplexSuperworker",
           :arg_keys=>[:first_argument],
           :arg_values=>[100],
           :status=>"initialized",
           :descendants_are_complete=>false},
         5=>
          {:subjob_id=>5,
           :parent_id=>3,
           :children_ids=>[6, 7],
           :next_id=>nil,
           :subworker_class=>"parallel",
           :superworker_class=>"ComplexSuperworker",
           :arg_keys=>[],
           :arg_values=>[],
           :status=>"initialized",
           :descendants_are_complete=>false},
           6=>
          {:subjob_id=>6,
           :parent_id=>5,
           :children_ids=>nil,
           :next_id=>7,
           :subworker_class=>"Worker5",
           :superworker_class=>"ComplexSuperworker",
           :arg_keys=>[:first_argument],
           :arg_values=>[100],
           :status=>"initialized",
           :descendants_are_complete=>false},
         7=>
          {:subjob_id=>7,
           :parent_id=>5,
           :children_ids=>[8, 9],
           :next_id=>nil,
           :subworker_class=>"Worker6",
           :superworker_class=>"ComplexSuperworker",
           :arg_keys=>[:first_argument],
           :arg_values=>[100],
           :status=>"initialized",
           :descendants_are_complete=>false},
         8=>
          {:subjob_id=>8,
           :parent_id=>7,
           :children_ids=>nil,
           :next_id=>9,
           :subworker_class=>"Worker7",
           :superworker_class=>"ComplexSuperworker",
           :arg_keys=>[:first_argument],
           :arg_values=>[100],
           :status=>"initialized",
           :descendants_are_complete=>false},
         9=>
          {:subjob_id=>9,
           :parent_id=>7,
           :children_ids=>nil,
           :next_id=>nil,
           :subworker_class=>"Worker8",
           :superworker_class=>"ComplexSuperworker",
           :arg_keys=>[:first_argument],
           :arg_values=>[100],
           :status=>"initialized",
           :descendants_are_complete=>false},
         10=>
          {:subjob_id=>10,
           :parent_id=>1,
           :children_ids=>nil,
           :next_id=>nil,
           :subworker_class=>"Worker9",
           :superworker_class=>"ComplexSuperworker",
           :arg_keys=>[:first_argument],
           :arg_values=>[100],
           :status=>"initialized",
           :descendants_are_complete=>false}
        }

        record_hashes = subjobs_to_indexed_hash(Sidekiq::Superworker::Subjob.all)

        record_hashes.should have(expected_record_hashes.length).items
        record_hashes.each do |subjob_id, record_hash|
          expected_record_hashes[subjob_id].should == record_hash
        end
      end

      it 'creates enough Subjob records' do
        Sidekiq::Superworker::Subjob.count.should == 10
      end

      it 'queues root-level subjobs' do
        Sidekiq::Superworker::Subjob.where(subjob_id: 1).first.status.should == 'queued'
      end

      it 'creates a Sidekiq job for the first root-level subjob' do
        jobs = @queue.to_a
        first_job = jobs.first

        jobs.should have(1).items
        first_job.klass.should == 'Worker1'
        first_job.args.should == [100]
      end
    end
  end

  describe '.perform_async cascade' do
    before :each do
      worker_perform_async(ComplexSuperworker)
    end

    after :each do
      clean_datastores
    end

    context 'complex superworker' do
      it 'sets the correct statuses after subjob #1 completes' do
        trigger_completion_of_sidekiq_job(1)
        subjob_statuses_should_equal(
          1 => 'complete',
          2 => 'queued',
          (3..10) => 'initialized' 
        )
      end

      it 'sets the correct statuses after subjob #2 completes' do
        trigger_completion_of_sidekiq_job(1)
        trigger_completion_of_sidekiq_job(2)
        subjob_statuses_should_equal(
          1 => 'complete',
          2 => 'complete',
          3 => 'queued',
          (4..10) => 'initialized' 
        )
      end

      it 'sets the correct statuses after subjob #3 completes' do
        trigger_completion_of_sidekiq_job(1)
        trigger_completion_of_sidekiq_job(2)
        trigger_completion_of_sidekiq_job(3)
        subjob_statuses_should_equal(
          1 => 'complete',
          2 => 'complete',
          3 => 'complete',
          4 => 'queued',
          (5..10) => 'initialized' 
        )
      end

      it 'sets the correct statuses after subjob #4 completes' do
        trigger_completion_of_sidekiq_job(1)
        trigger_completion_of_sidekiq_job(2)
        trigger_completion_of_sidekiq_job(3)
        trigger_completion_of_sidekiq_job(4)
        subjob_statuses_should_equal(
          1 => 'complete',
          2 => 'complete',
          3 => 'complete',
          4 => 'complete',
          5 => 'running',
          6 => 'queued',
          7 => 'queued',
          (8..10) => 'initialized' 
        )
      end

      # Complete #7 before #6 to test parallel block
      it 'sets the correct statuses after subjob #7 completes' do
        trigger_completion_of_sidekiq_job(1)
        trigger_completion_of_sidekiq_job(2)
        trigger_completion_of_sidekiq_job(3)
        trigger_completion_of_sidekiq_job(4)
        trigger_completion_of_sidekiq_job(7)
        subjob_statuses_should_equal(
          1 => 'complete',
          2 => 'complete',
          3 => 'complete',
          4 => 'complete',
          5 => 'running',
          6 => 'queued',
          7 => 'complete',
          8 => 'queued',
          (9..10) => 'initialized' 
        )
      end

      it 'sets the correct statuses after subjobs #8 and #9 complete' do
        trigger_completion_of_sidekiq_job(1)
        trigger_completion_of_sidekiq_job(2)
        trigger_completion_of_sidekiq_job(3)
        trigger_completion_of_sidekiq_job(4)
        trigger_completion_of_sidekiq_job(7)
        trigger_completion_of_sidekiq_job(8)
        trigger_completion_of_sidekiq_job(9)
        subjob_statuses_should_equal(
          1 => 'complete',
          2 => 'complete',
          3 => 'complete',
          4 => 'complete',
          5 => 'running',
          6 => 'queued',
          7 => 'complete',
          8 => 'complete',
          9 => 'complete',
          10 => 'initialized' 
        )
      end

      it 'sets the correct statuses after subjob #6 completes' do
        trigger_completion_of_sidekiq_job(1)
        trigger_completion_of_sidekiq_job(2)
        trigger_completion_of_sidekiq_job(3)
        trigger_completion_of_sidekiq_job(4)
        trigger_completion_of_sidekiq_job(7)
        trigger_completion_of_sidekiq_job(8)
        trigger_completion_of_sidekiq_job(9)
        trigger_completion_of_sidekiq_job(6)
        subjob_statuses_should_equal(
          1 => 'complete',
          2 => 'complete',
          3 => 'complete',
          4 => 'complete',
          5 => 'complete',
          6 => 'complete',
          7 => 'complete',
          8 => 'complete',
          9 => 'complete',
          10 => 'queued' 
        )
      end

      it 'sets the correct statuses after subjob #10 completes' do
        trigger_completion_of_sidekiq_job(1)
        trigger_completion_of_sidekiq_job(2)
        trigger_completion_of_sidekiq_job(3)
        trigger_completion_of_sidekiq_job(4)
        trigger_completion_of_sidekiq_job(7)
        trigger_completion_of_sidekiq_job(8)
        trigger_completion_of_sidekiq_job(9)
        trigger_completion_of_sidekiq_job(6)
        trigger_completion_of_sidekiq_job(10)
        subjob_statuses_should_equal(
          (1..10) => 'complete'
        )
      end
    end
  end

  def clean_datastores
    DatabaseCleaner.clean_with(:truncation)
    @queue.clear
  end

  def trigger_completion_of_sidekiq_job(subjob_id)
    jid = Sidekiq::Superworker::Subjob.where(subjob_id: subjob_id).first.jid
    job = find_sidekiq_job_by_jid(jid)
    Sidekiq::Superworker::Processor.new.complete(job.item, false)
    job.delete
  end

  def worker_perform_async(worker)
    worker.perform_async(100, 101)
  end

  def find_sidekiq_job_by_jid(jid)
    @queue.each do |job|
      return job if job.jid == jid
    end
    nil
  end

  def subjobs_to_indexed_hash(subjobs)
    attributes = [
      :subjob_id,
      :parent_id,
      :children_ids,
      :next_id,
      :subworker_class,
      :superworker_class,
      :arg_keys,
      :arg_values,
      :status,
      :descendants_are_complete
    ]

    hash_array = subjobs.collect do |subjob|
      attributes.inject({}) { |hash, attribute| hash[attribute] = subjob.send(attribute); hash }
    end
    add_indexes_to_subjobs_hash_array(hash_array)
  end

  def add_indexes_to_subjobs_hash_array(subjobs_array)
    subjobs_array.inject({}) { |hash, record_hash| hash[record_hash[:subjob_id]] = record_hash; hash }
  end

  def subjob_statuses_should_equal(hash)
    expected_statuses = {}
    hash.each do |ids, status|
      ids = [ids] unless ids.is_a?(Enumerable)
      ids.each { |id| expected_statuses[id] = status}
    end
    actual_statuses = Hash[Sidekiq::Superworker::Subjob.order(:subjob_id).collect { |subjob| [subjob.id, subjob.status] }]
    actual_statuses.should == expected_statuses
  end

  # Create dummy Sidekiq worker classes: Worker1..Worker9
  (1..9).each do |i|
    klass = Class.new do
      include Sidekiq::Worker

      sidekiq_options :queue => queue_name

      def perform
        nil
      end
    end

    Object.const_set("Worker#{i}", klass)
  end
end
