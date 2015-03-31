Sidekiq Superworker
===================
Define dependency graphs of Sidekiq jobs

Overview
--------

Sidekiq Superworker lets you create superworkers, which are simple or complex graphs of Sidekiq workers.

For example, you can define complex graphs of workers and use both serial and parallel worker configurations:

[![](https://raw.github.com/socialpandas/sidekiq-superworker/master/doc/diagram-complex.png)](https://raw.github.com/socialpandas/sidekiq-superworker/master/doc/diagram-complex.png)

*(Worker10 will run after Worker5, Worker7, Worker8, and Worker9 have all completed.)*

```ruby
Superworker.define(:MySuperworker, :user_id, :comment_id) do
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

You can also define simple serial sequences of workers:

[![](https://raw.github.com/socialpandas/sidekiq-superworker/master/doc/diagram-simple.png)](https://raw.github.com/socialpandas/sidekiq-superworker/master/doc/diagram-simple.png)

```ruby
Superworker.define(:MySuperworker, :user_id, :comment_id) do
  Worker1 :user_id, :comment_id
  Worker2 :comment_id
  Worker3 :user_id
end
```

Installation
------------

Include it in your Gemfile:

    gem 'sidekiq-superworker'

Usage
-----

First, define a superworker in a file that's included during the initialization of the app. If you're using Rails, you might do this in an initializer:

```ruby
# config/initializers/superworkers.rb

Superworker.define(:MySuperworker, :user_id, :comment_id) do
  Worker1 :user_id, :comment_id
  Worker2 :comment_id
end

Superworker.define(:MyOtherSuperworker, :comment_id) do
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
Superworker.define(:MySuperworker, :user_id, :comment_id) do
  Worker1 :user_id, :comment_id
  Worker2 :comment_id
  Worker3 :user_id
end
```

If you want to set any static arguments for the subworkers, you can do that by using any values that are not symbols (e.g. strings, integers, etc):

```ruby
Superworker.define(:MySuperworker, :user_id, :comment_id) do
  Worker1 100, :user_id, :comment_id
  Worker2 'all'
end
```

If a subworker doesn't take any arguments, you'll need to include parentheses after it:

```ruby
Superworker.define(:MySuperworker, :user_id, :comment_id) do
  Worker1 :user_id, :comment_id
  Worker2()
end
```

### Namespaced Workers

To refer to a namespaced worker (e.g. `MyModule::Worker1`), replace the two colons with two underscores:

```ruby
Superworker.define(:MySuperworker, :user_id, :comment_id) do
  MyModule__Worker1 :user_id, :comment_id
end
```

### Options

#### Delete subjobs after their superjob completes

When a superjob is queued, records for all of its subjobs are created. By default, these records are deleted after the superjob completes. This can be changed by setting the following option to false:

```ruby
# config/initializers/superworker.rb
Sidekiq::Superworker.options[:delete_subjobs_after_superjob_completes] = false
```

#### Expire superworkers

When a subjob dies due to too many retries depending jobs will never run and the superjob will never be completed. Therefore the sujob redis keys will never be removed.
When setting `superjob_expiration` to *x* the subjobs keys will expire in *x* seconds. Default value is `nil` (the keys will never expire).

```ruby
# config/initializers/superworker.rb
Sidekiq::Superworker.options[:superjob_expiration] = 2592000 # 1 Month
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

Using [sidekiq_monitor](https://github.com/socialpandas/sidekiq_monitor) with Sidekiq Superworker is encouraged, as it lets you easily monitor when a superjob is running, when it has finished, whether it has encountered errors, and the status of all of its subjobs.

### Batch Jobs

By using a `batch` block, you can create batches of subjobs that are all associated with the superjob. The following will run Worker1 and Worker2 in serial for every user ID in the array passed to perform_async.

```ruby
Superworker.define(:MyBatchSuperworker, :user_ids) do
  batch user_ids: :user_id do
    Worker1 :user_id
    Worker2 :user_id
  end
end

MyBatchSuperworker.perform_async([30, 31, 32, 33, 34, 35])
```

You can also use multiple arguments:

```ruby
Superworker.define(:MyBatchSuperworker, :user_ids, :comment_ids) do
  batch user_ids: :user_id, comment_ids: :comment_id do
    Worker1 :user_id, :comment_id
    Worker2 :user_id
  end
end

MyBatchSuperworker.perform_async([10, 11, 12], [20, 21, 22])
```

The above produces a sequence equivalent to this (the workers run serially):

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

Upgrade Notes
-------------

### Upgrading from 1.0.x to 1.1.x while using Sidekiq Monitor

If you're using Sidekiq Monitor, were previously using Sidekiq Superworker 1.0.x, and are upgrading to 1.1.x, you should be aware that the strategy for storing subjob IDs has changed. Before upgrading, you should let all of your superworkers finish, then upgrade, then resume running your superworkers. For superjobs that ran before the upgrade, the relationship between superjobs and subjobs will no longer be shown in some parts of the UI. If you're not using Sidekiq Monitor, you can upgrade without any interruption.

### Upgrading from 0.x to 1.x

If you were previously using Sidekiq Superworker 0.x and are upgrading to 1.x, there are some changes to be aware of:

#### Redis replaced ActiveRecord

ActiveRecord was used as the datastore in 0.x due to application-specific requirements, but Redis is a far better choice for many reasons, especially given that Sidekiq uses Redis. When upgrading to 1.x, you'll need to let all of your superjobs complete, then upgrade to 1.x, then resume running superjobs. You can drop the 'sidekiq_superworker_subjobs' table, if you like.

#### Superworker.define replaced Superworker.create

The name of the `Superworker.create` method caused confusion, as some users would call it multiple times. Since it defines a class, it's been renamed to `Superworker.define`. You'll need to replace it accordingly.

Testing
-------

Sidekiq Superworker is tested against multiple sets of gem dependencies (currently: no gems, Rails 3, and Rails 4), so please run the tests with [Appraisal](https://github.com/thoughtbot/appraisal) before submitting a PR. Thanks!

```bash
appraisal rspec
```

License
-------

Sidekiq Superworker is released under the MIT License. Please see the MIT-LICENSE file for details.
