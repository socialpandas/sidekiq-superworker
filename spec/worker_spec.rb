require 'spec_helper'

describe Sidekiq::Superworker::Worker do
  include Sidekiq::Superworker::WorkerHelpers

  describe '.create' do
    it 'creates a superworker class' do
      described_class.create(:MySuperworker) do
        Worker1()
      end
      MySuperworker.should be_a(Class)
      MySuperworker.ancestors.should include(Sidekiq::Superworker::WorkerClass)
    end

    it 'creates a superworker class within a module' do
      module MyModule; end
      described_class.create('MyModule::MySuperworker') do
        Worker1()
      end
      MyModule::MySuperworker.should be_a(Class)
      MyModule::MySuperworker.ancestors.should include(Sidekiq::Superworker::WorkerClass)
    end

    it 'creates a superworker class within a nested module' do
      module MyModule
        module MyNestedModule; end
      end
      described_class.create('MyModule::MyNestedModule::MySuperworker') do
        Worker1()
      end
      MyModule::MyNestedModule::MySuperworker.should be_a(Class)
      MyModule::MyNestedModule::MySuperworker.ancestors.should include(Sidekiq::Superworker::WorkerClass)
    end
  end
end
