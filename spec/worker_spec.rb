require 'spec_helper'

describe Sidekiq::Superworker::Worker do
  include Sidekiq::Superworker::WorkerHelpers

  describe '.define' do
    it 'creates a superworker class' do
      described_class.define(:MySuperworker) do
        Worker1()
      end
      MySuperworker.should be_a(Class)
      MySuperworker.ancestors.should include(Sidekiq::Superworker::WorkerClass)
    end

    it 'creates a superworker class within a module' do
      module MyModule; end
      described_class.define('MyModule::MySuperworker') do
        Worker1()
      end
      MyModule::MySuperworker.should be_a(Class)
      MyModule::MySuperworker.ancestors.should include(Sidekiq::Superworker::WorkerClass)
    end

    it 'creates a superworker class within a nested module' do
      module MyModule
        module MyNestedModule; end
      end
      described_class.define('MyModule::MyNestedModule::MySuperworker') do
        Worker1()
      end
      MyModule::MyNestedModule::MySuperworker.should be_a(Class)
      MyModule::MyNestedModule::MySuperworker.ancestors.should include(Sidekiq::Superworker::WorkerClass)
    end
  end
end
