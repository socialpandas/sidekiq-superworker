require 'spec_helper'

describe Sidekiq::Superworker::DSLParser do
  include Sidekiq::Superworker::WorkerHelpers

  let(:parser) { described_class.new }

  describe '#method_to_subworker_type' do
    it 'preserves batch' do
      parser.method_to_subworker_type(:batch).should == :batch
    end

    it 'preserves parallel' do
      parser.method_to_subworker_type(:parallel).should == :parallel
    end

    it 'preserves a class name' do
      parser.method_to_subworker_type(:MyWorker).should == :MyWorker
    end

    it 'preserves two underscores if the class exists' do
      class My__UnderscoredClass; end
      parser.method_to_subworker_type(:My__UnderscoredClass).should == 'My__UnderscoredClass'
    end

    it 'converts two underscores to a module specification if the module exists' do
      module MyModule
        class Worker1; end
      end
      parser.method_to_subworker_type(:MyModule__Worker1).should == 'MyModule::Worker1'
    end
  end

  describe '#parse' do
    it 'calls method_to_subworker_type' do
      block = proc do
        Worker1 :user_id
      end
      
      parser.should_receive(:method_to_subworker_type).with(:Worker1).once.and_return("Worker1")
      parser.parse(block)
    end

    context 'batch superworker with one array argument' do
      it 'returns the correct nested hash' do
        block = proc do
          batch user_ids: :user_id do
            Worker1 :user_id
            Worker2 :user_id
            Worker3 :user_id
          end
        end
        
        nested_hash = parser.parse(block)
        nested_hash.should ==
          {1=>
            {:subworker_class=>:batch,
             :arg_keys=>[{:user_ids=>:user_id}],
             :children=>
              {2=>{:subworker_class=>:Worker1, :arg_keys=>[:user_id]},
               3=>{:subworker_class=>:Worker2, :arg_keys=>[:user_id]},
               4=>{:subworker_class=>:Worker3, :arg_keys=>[:user_id]}}}}
      end
    end

    context 'batch superworker with two array arguments' do
      it 'returns the correct nested hash' do
        block = proc do
          batch user_ids: :user_id, comment_ids: :comment_id do
            Worker1 :comment_id
            Worker2 :user_id
            Worker3 :user_id
          end
        end
        
        nested_hash = parser.parse(block)
        nested_hash.should ==
          {1=>
            {:subworker_class=>:batch,
             :arg_keys=>[{:user_ids=>:user_id, :comment_ids=>:comment_id}],
             :children=>
              {2=>{:subworker_class=>:Worker1, :arg_keys=>[:comment_id]},
               3=>{:subworker_class=>:Worker2, :arg_keys=>[:user_id]},
               4=>{:subworker_class=>:Worker3, :arg_keys=>[:user_id]}}}}
      end
    end

    context 'batch superworker with nested superworker' do
      it 'returns the correct nested hash' do
        Sidekiq::Superworker::Worker.define(:BatchChildSuperworker, :user_id) do
          Worker2 :user_id do
            Worker3 :user_id
          end
        end

        block = proc do
          batch user_ids: :user_id do
            BatchChildSuperworker :user_id
          end
        end
        
        nested_hash = parser.parse(block)
        nested_hash.should ==
          {1=>
            {:subworker_class=>:batch,
             :arg_keys=>[{:user_ids=>:user_id}],
             :children=>
              {2=>
                {:subworker_class=>:BatchChildSuperworker,
                 :arg_keys=>[:user_id],
                 :children=>
                  {3=>
                    {:subworker_class=>:Worker2,
                     :arg_keys=>[:user_id],
                     :children=>
                      {4=>{:subworker_class=>:Worker3, :arg_keys=>[:user_id]}}}}}}}}
      end
    end

    context 'complex superworker' do
      it 'returns the correct nested hash' do
        block = proc do
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
        
        nested_hash = parser.parse(block)
        nested_hash.should ==
          {1=>
            {:subworker_class=>:Worker1,
             :arg_keys=>[:first_argument],
             :children=>
              {2=>{:subworker_class=>:Worker2, :arg_keys=>[:second_argument]},
               3=>
                {:subworker_class=>:Worker3,
                 :arg_keys=>[:second_argument],
                 :children=>
                  {4=>{:subworker_class=>:Worker4, :arg_keys=>[:first_argument]},
                   5=>
                    {:subworker_class=>:parallel,
                     :arg_keys=>[],
                     :children=>
                      {6=>{:subworker_class=>:Worker5, :arg_keys=>[:first_argument]},
                       7=>
                        {:subworker_class=>:Worker6,
                         :arg_keys=>[:first_argument],
                         :children=>
                          {8=>{:subworker_class=>:Worker7, :arg_keys=>[:first_argument]},
                           9=>
                            {:subworker_class=>:Worker8,
                             :arg_keys=>[:first_argument]}}}}}}},
               10=>{:subworker_class=>:Worker9, :arg_keys=>[:first_argument]}}}}
      end
    end

    context 'nested parallel superworker' do
      it 'returns the correct records' do
        Sidekiq::Superworker::Worker.define(:Superworker1, :first_argument) do
          Worker2 :first_argument do
            Worker3 :first_argument
          end
        end

        block = proc do
          parallel do
            Worker1 :first_argument
            Superworker1 :first_argument do
              parallel do
                Worker4 :first_argument
                Worker5 :first_argument
              end
            end
          end
          Worker1 :first_argument
        end
        nested_hash = parser.parse(block)
        nested_hash.should ==
          {1=>
            {:subworker_class=>:parallel,
             :arg_keys=>[],
             :children=>
              {2=>{:subworker_class=>:Worker1, :arg_keys=>[:first_argument]},
               3=>
                {:subworker_class=>:Superworker1,
                 :arg_keys=>[:first_argument],
                 :children=>
                  {4=>
                    {:subworker_class=>:Worker2,
                     :arg_keys=>[:first_argument],
                     :children=>
                      {5=>{:subworker_class=>:Worker3, :arg_keys=>[:first_argument]}}},
                   6=>
                    {:subworker_class=>:parallel,
                     :arg_keys=>[],
                     :children=>
                      {7=>{:subworker_class=>:Worker4, :arg_keys=>[:first_argument]},
                       8=>
                        {:subworker_class=>:Worker5, :arg_keys=>[:first_argument]}}}}}}},
           9=>{:subworker_class=>:Worker1, :arg_keys=>[:first_argument]}}
      end
    end
  end
end
