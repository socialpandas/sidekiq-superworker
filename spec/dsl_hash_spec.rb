require 'spec_helper'

describe Sidekiq::Superworker::DSLHash do
  include Sidekiq::Superworker::WorkerHelpers

  before :all do
    create_dummy_workers
  end

  describe '#get_batch_iteration_arg_value_arrays' do
    context 'one array argument' do
      it 'returns the arrays' do
        dsl_hash = Sidekiq::Superworker::DSLHash.new({})
        dsl_hash.instance_variable_set(:@args, { first_arguments: [10, 11, 12] })
        arrays = dsl_hash.send(:get_batch_iteration_arg_value_arrays, { first_arguments: :first_argument })
        arrays.should == [[10], [11], [12]]
      end
    end

    context 'two array arguments' do
      it 'returns the arrays' do
        dsl_hash = Sidekiq::Superworker::DSLHash.new({})
        dsl_hash.instance_variable_set(:@args, { first_arguments: [10, 11, 12], second_arguments: [20, 21, 22] })
        arrays = dsl_hash.send(:get_batch_iteration_arg_value_arrays, { first_arguments: :first_argument, second_arguments: :second_argument })
        arrays.should == [[10, 20], [11, 21], [12, 22]]
      end
    end
  end

  describe '#rewrite_record_ids' do
    context 'hash with children' do
      it 'rewrites the record ids' do
        hash =
          {1=>
            {:subworker_class=>:Worker1,
             :arg_keys=>[:first_argument],
             :children=>{
              2=>{:subworker_class=>:Worker2, :arg_keys=>[:first_argument]}}}}
        dsl_hash = Sidekiq::Superworker::DSLHash.new(hash)
        dsl_hash.rewrite_record_ids(5).should ==
          {5=>
            {:subworker_class=>:Worker1,
             :arg_keys=>[:first_argument],
             :children=>{
              6=>{:subworker_class=>:Worker2, :arg_keys=>[:first_argument]}}}}
      end
    end
  end

  describe '#to_records' do
    context 'batch superworker with one array argument' do
      it 'returns the correct records' do
        block = proc do
          batch first_arguments: :first_argument do
            Worker1 :first_argument
            Worker2 :first_argument
          end
        end

        hash = Sidekiq::Superworker::DSLParser.new.parse(block)
        args = {
          first_arguments: [10, 11, 12]
        }
        dsl_hash = Sidekiq::Superworker::DSLHash.new(hash, args)
        dsl_hash.to_records.should ==
          {1=>
            {:subjob_id=>1,
             :subworker_class=>"batch",
             :arg_keys=>[{:first_arguments=>:first_argument}],
             :arg_values=>[{:first_arguments=>:first_argument}],
             :parent_id=>nil,
             :children_ids=>[2, 5, 8]},
           2=>
            {:subjob_id=>2,
             :subworker_class=>"batch_child",
             :arg_keys=>[:first_argument],
             :arg_values=>[10],
             :parent_id=>1},
           3=>
            {:subworker_class=>:Worker1,
             :arg_keys=>[:first_argument],
             :subjob_id=>3,
             :parent_id=>2,
             :arg_values=>[10],
             :next_id=>4},
           4=>
            {:subworker_class=>:Worker2,
             :arg_keys=>[:first_argument],
             :subjob_id=>4,
             :parent_id=>2,
             :arg_values=>[10]},
           5=>
            {:subjob_id=>5,
             :subworker_class=>"batch_child",
             :arg_keys=>[:first_argument],
             :arg_values=>[11],
             :parent_id=>1},
           6=>
            {:subworker_class=>:Worker1,
             :arg_keys=>[:first_argument],
             :subjob_id=>6,
             :parent_id=>5,
             :arg_values=>[11],
             :next_id=>7},
           7=>
            {:subworker_class=>:Worker2,
             :arg_keys=>[:first_argument],
             :subjob_id=>7,
             :parent_id=>5,
             :arg_values=>[11]},
           8=>
            {:subjob_id=>8,
             :subworker_class=>"batch_child",
             :arg_keys=>[:first_argument],
             :arg_values=>[12],
             :parent_id=>1},
           9=>
            {:subworker_class=>:Worker1,
             :arg_keys=>[:first_argument],
             :subjob_id=>9,
             :parent_id=>8,
             :arg_values=>[12],
             :next_id=>10},
           10=>
            {:subworker_class=>:Worker2,
             :arg_keys=>[:first_argument],
             :subjob_id=>10,
             :parent_id=>8,
             :arg_values=>[12]}}
      end
    end

    context 'batch superworker with two array arguments' do
      it 'returns the correct records' do
        block = proc do
          batch first_arguments: :first_argument, second_arguments: :second_argument do
            Worker1 :first_argument
            Worker2 :first_argument, :second_argument
          end
        end
        
        hash = Sidekiq::Superworker::DSLParser.new.parse(block)
        args = {
          first_arguments: [10, 11, 12],
          second_arguments: [20, 21, 22]
        }
        dsl_hash = Sidekiq::Superworker::DSLHash.new(hash, args)
        dsl_hash.to_records.should ==
          {1=>
            {:subjob_id=>1,
             :subworker_class=>"batch",
             :arg_keys=>
              [{:first_arguments=>:first_argument, :second_arguments=>:second_argument}],
             :arg_values=>
              [{:first_arguments=>:first_argument, :second_arguments=>:second_argument}],
             :parent_id=>nil,
             :children_ids=>[2, 5, 8]},
           2=>
            {:subjob_id=>2,
             :subworker_class=>"batch_child",
             :arg_keys=>[:first_argument, :second_argument],
             :arg_values=>[10, 20],
             :parent_id=>1},
           3=>
            {:subworker_class=>:Worker1,
             :arg_keys=>[:first_argument],
             :subjob_id=>3,
             :parent_id=>2,
             :arg_values=>[10, 20],
             :next_id=>4},
           4=>
            {:subworker_class=>:Worker2,
             :arg_keys=>[:first_argument, :second_argument],
             :subjob_id=>4,
             :parent_id=>2,
             :arg_values=>[10, 20]},
           5=>
            {:subjob_id=>5,
             :subworker_class=>"batch_child",
             :arg_keys=>[:first_argument, :second_argument],
             :arg_values=>[11, 21],
             :parent_id=>1},
           6=>
            {:subworker_class=>:Worker1,
             :arg_keys=>[:first_argument],
             :subjob_id=>6,
             :parent_id=>5,
             :arg_values=>[11, 21],
             :next_id=>7},
           7=>
            {:subworker_class=>:Worker2,
             :arg_keys=>[:first_argument, :second_argument],
             :subjob_id=>7,
             :parent_id=>5,
             :arg_values=>[11, 21]},
           8=>
            {:subjob_id=>8,
             :subworker_class=>"batch_child",
             :arg_keys=>[:first_argument, :second_argument],
             :arg_values=>[12, 22],
             :parent_id=>1},
           9=>
            {:subworker_class=>:Worker1,
             :arg_keys=>[:first_argument],
             :subjob_id=>9,
             :parent_id=>8,
             :arg_values=>[12, 22],
             :next_id=>10},
           10=>
            {:subworker_class=>:Worker2,
             :arg_keys=>[:first_argument, :second_argument],
             :subjob_id=>10,
             :parent_id=>8,
             :arg_values=>[12, 22]}}
      end
    end

    context 'batch superworker with nested superworker' do
      it 'returns the correct nested hash' do
        Sidekiq::Superworker::Worker.create(:BatchNestedSuperworker, :first_argument) do
          Worker2 :first_argument do
            Worker3 :first_argument
          end
        end

        block = proc do
          batch first_arguments: :first_argument do
            BatchNestedSuperworker :first_argument
          end
        end
        
        hash = Sidekiq::Superworker::DSLParser.new.parse(block)

        args = {
          first_arguments: [10, 11]
        }
        dsl_hash = Sidekiq::Superworker::DSLHash.new(hash, args)
        dsl_hash.to_records.should ==
          {1=>
            {:subjob_id=>1,
             :subworker_class=>"batch",
             :arg_keys=>[{:first_arguments=>:first_argument}],
             :arg_values=>[{:first_arguments=>:first_argument}],
             :parent_id=>nil,
             :children_ids=>[2, 6]},
           2=>
            {:subjob_id=>2,
             :subworker_class=>"batch_child",
             :arg_keys=>[:first_argument],
             :arg_values=>[10],
             :parent_id=>1},
           3=>
            {:subworker_class=>:BatchNestedSuperworker,
             :arg_keys=>[:first_argument],
             :subjob_id=>3,
             :parent_id=>2,
             :arg_values=>[10],
             :children_ids=>[4]},
           4=>
            {:subjob_id=>4,
             :subworker_class=>"Worker2",
             :arg_keys=>[:first_argument],
             :arg_values=>[10],
             :parent_id=>3,
             :children_ids=>[5]},
           5=>
            {:subjob_id=>5,
             :subworker_class=>"Worker3",
             :arg_keys=>[:first_argument],
             :arg_values=>[10],
             :parent_id=>4},
           6=>
            {:subjob_id=>6,
             :subworker_class=>"batch_child",
             :arg_keys=>[:first_argument],
             :arg_values=>[11],
             :parent_id=>1},
           7=>
            {:subworker_class=>:BatchNestedSuperworker,
             :arg_keys=>[:first_argument],
             :subjob_id=>7,
             :parent_id=>6,
             :arg_values=>[11],
             :children_ids=>[8]},
           8=>
            {:subjob_id=>8,
             :subworker_class=>"Worker2",
             :arg_keys=>[:first_argument],
             :arg_values=>[11],
             :parent_id=>7,
             :children_ids=>[9]},
           9=>
            {:subjob_id=>9,
             :subworker_class=>"Worker3",
             :arg_keys=>[:first_argument],
             :arg_values=>[11],
             :parent_id=>8}}
      end
    end

    context 'batch superworker with nested superworker and worker' do
      it 'returns the correct nested hash' do
        Sidekiq::Superworker::Worker.create(:BatchNestedChildSuperworker, :first_argument) do
          Worker2 :first_argument do
            Worker3 :first_argument
          end
        end

        block = proc do
          batch first_arguments: :first_argument do
            BatchNestedChildSuperworker :first_argument
            Worker1 :first_argument
          end
        end
        
        hash = Sidekiq::Superworker::DSLParser.new.parse(block)

        args = {
          first_arguments: [10, 11]
        }
        dsl_hash = Sidekiq::Superworker::DSLHash.new(hash, args)
        dsl_hash.to_records.should ==
          {1=>
            {:subjob_id=>1,
             :subworker_class=>"batch",
             :arg_keys=>[{:first_arguments=>:first_argument}],
             :arg_values=>[{:first_arguments=>:first_argument}],
             :parent_id=>nil,
             :children_ids=>[2, 7]},
           2=>
            {:subjob_id=>2,
             :subworker_class=>"batch_child",
             :arg_keys=>[:first_argument],
             :arg_values=>[10],
             :parent_id=>1},
           3=>
            {:subworker_class=>:BatchNestedChildSuperworker,
             :arg_keys=>[:first_argument],
             :subjob_id=>3,
             :parent_id=>2,
             :arg_values=>[10],
             :children_ids=>[4],
             :next_id=>6},
           4=>
            {:subjob_id=>4,
             :subworker_class=>"Worker2",
             :arg_keys=>[:first_argument],
             :arg_values=>[10],
             :parent_id=>3,
             :children_ids=>[5]},
           5=>
            {:subjob_id=>5,
             :subworker_class=>"Worker3",
             :arg_keys=>[:first_argument],
             :arg_values=>[10],
             :parent_id=>4},
           6=>
            {:subworker_class=>:Worker1,
             :arg_keys=>[:first_argument],
             :subjob_id=>6,
             :parent_id=>2,
             :arg_values=>[10]},
           7=>
            {:subjob_id=>7,
             :subworker_class=>"batch_child",
             :arg_keys=>[:first_argument],
             :arg_values=>[11],
             :parent_id=>1},
           8=>
            {:subworker_class=>:BatchNestedChildSuperworker,
             :arg_keys=>[:first_argument],
             :subjob_id=>8,
             :parent_id=>7,
             :arg_values=>[11],
             :children_ids=>[9],
             :next_id=>11},
           9=>
            {:subjob_id=>9,
             :subworker_class=>"Worker2",
             :arg_keys=>[:first_argument],
             :arg_values=>[11],
             :parent_id=>8,
             :children_ids=>[10]},
           10=>
            {:subjob_id=>10,
             :subworker_class=>"Worker3",
             :arg_keys=>[:first_argument],
             :arg_values=>[11],
             :parent_id=>9},
           11=>
            {:subworker_class=>:Worker1,
             :arg_keys=>[:first_argument],
             :subjob_id=>11,
             :parent_id=>7,
             :arg_values=>[11]}}
      end
    end
  end
end
