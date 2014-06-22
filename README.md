Sidekiq Superworker
===================
Chain together Sidekiq workers in parallel and/or serial configurations

Overview
--------

Sidekiq Superworker lets you create superworkers, which are simple or complex chains of Sidekiq workers.

For example, you can define complex chains of workers, and even use parallel blocks:

[![](https://raw.github.com/socialpandas/sidekiq-superworker/master/doc/diagram-complex.png)](https://raw.github.com/socialpandas/sidekiq-superworker/master/doc/diagram-complex.png)

*(Worker10 will run after Worker5, Worker7, Worker8, and Worker9 have all completed.)*

```ruby
Superworker.create(:MySuperworker, :user_id, :comment_id) do
  Worker1 :user_id
  Worker2 :user_id do
    parallel do
      Worker3 :comment_id do
        Worker4 :comment_id
        Worker5 :comment_id
      end
      Worker6 :user_id do
        parallel do
          Worker7 :user_id
          Worker8 :user_id
          Worker9 :user_id
        end
      end
    end
    Worker10 :comment_id
  end
end
```

And you can run it like any other worker:

```ruby
MySuperworker.perform_async(23, 852)
```

You can also define simple serial chains of workers:

[![](https://raw.github.com/socialpandas/sidekiq-superworker/master/doc/diagram-simple.png)](https://raw.github.com/socialpandas/sidekiq-superworker/master/doc/diagram-simple.png)

```ruby
Superworker.create(:MySuperworker, :user_id, :comment_id) do
  Worker1 :user_id, :comment_id
  Worker2 :comment_id
  Worker3 :user_id
end
```

Installation
------------

Include it in your Gemfile:

    gem 'sidekiq-superworker'

Install and run the migration:

    rails g sidekiq:superworker:install
    rake db:migrate

Usage
-----

First, define a superworker in a file that's included during the initialization of the app. If you're using Rails, you might do this in an initializer:

```ruby
# config/initializers/superworkers.rb

Superworker.create(:MySuperworker, :user_id, :comment_id) do
  Worker1 :user_id, :comment_id
  Worker2 :comment_id
end

Superworker.create(:MyOtherSuperworker, :comment_id) do
  Worker2 :comment_id
  Worker3 :comment_id
end
```

To run a superworker, call perform_async:

```ruby
MySuperworker.perform_async(23, 852)
```

### Arguments

You can define any number of arguments for the superworker and pass them to different subworkers as you see fit:

```ruby
Superworker.create(:MySuperworker, :user_id, :comment_id) do
  Worker1 :user_id, :comment_id
  Worker2 :comment_id
  Worker3 :user_id
end
```

If you want to set any static arguments for the subworkers, you can do that by using any values that are not symbols (e.g. strings, integers, etc):

```ruby
Superworker.create(:MySuperworker, :user_id, :comment_id) do
  Worker1 100, :user_id, :comment_id
  Worker2 'all'
end
```

If a subworker doesn't take any arguments, you'll need to include parentheses after it:

```ruby
Superworker.create(:MySuperworker, :user_id, :comment_id) do
  Worker1 :user_id, :comment_id
  Worker2()
end
```

### Namespaced Workers

To refer to a namespaced worker (e.g. `MyModule::Worker1`), replace the two colons with two underscores:

```ruby
Superworker.create(:MySuperworker, :user_id, :comment_id) do
  MyModule__Worker1 :user_id, :comment_id
end
```

### Options

#### Insert Method

When a superjob is queued, records for all of its subjobs are created. By default, each subjob record will be created using a separate insert query. If you're creating superjobs with large numbers of subjobs and want to improve performance, you can create these records using a multiple insert query instead. To this, set `:insert_method` to `:multiple`:

```ruby
# config/initializers/superworker.rb
Sidekiq::Superworker.options[:insert_method] = :multiple
```

### Logging

To make debugging easier, Sidekiq Superworker provides detailed log messages when its logger is set to the DEBUG level:

```ruby
# config/initializers/superworker.rb
logger = Logger.new(Rails.root.join('log', 'superworker.log'))
logger.level = Logger::DEBUG
Sidekiq::Superworker::Logging.logger = logger
```

### Monitoring

Using [sidekiq_monitor](https://github.com/socialpandas/sidekiq_monitor) with Sidekiq Superworker is strongly encouraged, as it lets you easily monitor when a superjob is running, when it has finished, whether it has encountered errors, and the status of all of its subjobs.

### Batch Jobs

By using a `batch` block, you can create batches of subjobs that are all associated with the superjob. The following will run Worker1 and Worker2 in serial for every user ID in the array passed to perform_async.

```ruby
Superworker.create(:MyBatchSuperworker, :user_ids) do
  batch user_ids: :user_id do
    Worker1 :user_id
    Worker2 :user_id
  end
end

MyBatchSuperworker.perform_async([30, 31, 32, 33, 34, 35])
```

You can also use multiple arguments:

```ruby
Superworker.create(:MyBatchSuperworker, :user_ids, :comment_ids) do
  batch user_ids: :user_id, comment_ids: :comment_id do
    Worker1 :user_id, :comment_id
    Worker2 :user_id
  end
end

MyBatchSuperworker.perform_async([10, 11, 12], [20, 21, 22])
```

The above produces the a sequence equivalent to this (the workers run serially):

```ruby
Worker1.new.perform(10, 20)
Worker2.new.perform(10)
Worker1.new.perform(11, 21)
Worker2.new.perform(11)
Worker1.new.perform(12, 22)
Worker2.new.perform(12)
```

Grouping jobs into batches greatly improves your ability to audit them and determine when batches have finished.

### Superjob Names

If you're using sidekiq_monitor and want to set a name for a superjob, you can set it in an additional argument, like so:

```ruby
# Unnamed
MySuperworker.perform_async(23)

# Named
MySuperworker.perform_async(23, name: 'My job name')
```

### Errors

If a subjob encounters an exception, the subjobs that depend on it won't run, but the rest of the subjobs will continue as usual.

If sidekiq_monitor is being used, the exception will be bubbled up to the superjob, which lets you easily see when your superjobs have failed.

License
-------

Sidekiq Superworker is released under the MIT License. Please see the MIT-LICENSE file for details.
