# Create dummy Sidekiq worker classes: Worker1..Worker9
(1..9).each do |i|
  class_name = "Worker#{i}"
  klass = Class.new do
    include Sidekiq::Worker

    sidekiq_options :queue => 'sidekiq_superworker_test'

    def perform
      nil
    end
  end

  Object.const_set(class_name, klass)
end

# For testing worker exceptions
class FailingWorker
  include Sidekiq::Worker

  sidekiq_options :queue => 'sidekiq_superworker_test'

  def perform
    raise RuntimeError
  end
end

# For testing simple superworker properties
Sidekiq::Superworker::Worker.create(:SimpleSuperworker, :first_argument, :second_argument) do
  Worker1 :first_argument
  Worker2 :second_argument
end


# For testing complex blocks
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

# For testing batch blocks
Sidekiq::Superworker::Worker.create(:BatchSuperworker, :user_ids) do
  batch user_ids: :user_id do
    Worker1 :user_id
    Worker2 :user_id
  end
end

# For testing empty arguments
Sidekiq::Superworker::Worker.create(:EmptyArgumentsSuperworker) do
  Worker1 do
    Worker2()
  end
end

# For testing nested superworkers
Sidekiq::Superworker::Worker.create(:ChildSuperworker) do
  Worker2 do
    Worker3()
  end
end
Sidekiq::Superworker::Worker.create(:NestedSuperworker) do
  Worker1()
  ChildSuperworker()
end

# For testing exceptions
Sidekiq::Superworker::Worker.create(:FailingSuperworker, :first_argument) do
  Worker1 :first_argument do        # 1
    parallel do                     # 2
      FailingWorker :first_argument # 3
      Worker2 :first_argument       # 4
    end
  end
  Worker3 :first_argument           # 5
end

