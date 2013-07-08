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

Grouping jobs into batches greatly improves your ability to audit them and determine when batches have finished.

### Errors

If a subjob encounters an exception, the subjobs that depend on it won't run, but the rest of the subjobs will continue as usual.

If sidekiq_monitor is being used, the exception will be bubbled up to the superjob, which lets you easily see when your superjobs have failed.

License
-------

Sidekiq Superworker is released under the MIT License. Please see the MIT-LICENSE file for details.
