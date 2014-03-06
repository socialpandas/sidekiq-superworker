require 'spec_helper'

describe Sidekiq::Superworker::Worker do
  include Sidekiq::Superworker::WorkerHelpers

  before :all do
    create_dummy_workers
  end

  describe '.create' do
    it 'creates a worker class' do
      Sidekiq::Superworker::Worker.create(:MySuperworker) do
        Worker1()
      end
      MySuperworker.should be_a(Class)
      MySuperworker.ancestors.should include(Sidekiq::Superworker::WorkerClass)
    end

    it 'creates a worker class within a module' do
      module MyModule; end
      Sidekiq::Superworker::Worker.create('MyModule::MySuperworker') do
        Worker1()
      end
      MyModule::MySuperworker.should be_a(Class)
      MyModule::MySuperworker.ancestors.should include(Sidekiq::Superworker::WorkerClass)
    end

    it 'creates a worker class within a nested module' do
      module MyModule
        module MyNestedModule; end
      end
      Sidekiq::Superworker::Worker.create('MyModule::MyNestedModule::MySuperworker') do
        Worker1()
      end
      MyModule::MyNestedModule::MySuperworker.should be_a(Class)
      MyModule::MyNestedModule::MySuperworker.ancestors.should include(Sidekiq::Superworker::WorkerClass)
    end
  end
end
