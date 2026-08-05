# Auto-instrumentation

The distribution enables all libraries in [`opentelemetry-instrumentation-all`](https://github.com/open-telemetry/opentelemetry-ruby-contrib) automatically.
No configuration is needed — each instrumentation activates when its target library loads.

## How it works

At startup the distribution performs an initial sweep of already-loaded libraries and installs compatible instrumentations.
If any instrumentation's target library has not yet loaded, the distribution also installs a `TracePoint(:end)` hook that fires whenever a class or module finishes being defined, so libraries loaded later are caught automatically.
No specific load order is required.

To restrict which instrumentations are enabled, set `OTEL_RUBY_ENABLED_INSTRUMENTATIONS` to a comma-separated list of snake_case instrumentation names:

```sh
OTEL_RUBY_ENABLED_INSTRUMENTATIONS=net_http,rack,active_record
```

When this variable is unset, all supported instrumentations are enabled.

## Bundled instrumentations

### Web frameworks

| Library | Gem | Instrumentation name |
| --- | --- | --- |
| Rails (request handling) | `rails` | `rails` |
| Rack (middleware) | `rack` | `rack` |
| Sinatra | `sinatra` | `sinatra` |
| Grape (API framework) | `grape` | `grape` |

### Rails components

| Library | Gem | Instrumentation name |
| --- | --- | --- |
| Action Mailer (email) | `actionmailer` | `action_mailer` |
| Action Pack (controllers) | `actionpack` | `action_pack` |
| Action View (view rendering) | `actionview` | `action_view` |
| Active Job (background jobs) | `activejob` | `active_job` |
| Active Model Serializers (JSON) | `active_model_serializers` | `active_model_serializers` |
| Active Record (ORM) | `activerecord` | `active_record` |
| Active Storage (file uploads) | `activestorage` | `active_storage` |
| Active Support (notifications) | `activesupport` | `active_support` |

### HTTP clients

| Library | Gem | Instrumentation name |
| --- | --- | --- |
| Ethon (libcurl) | `ethon` | `ethon` |
| Excon | `excon` | `excon` |
| Faraday | `faraday` | `faraday` |
| HTTP.rb | `http` | `http` |
| HTTPClient | `httpclient` | `http_client` |
| HTTPX | `httpx` | `httpx` |
| Net::HTTP (Ruby stdlib) | `net-http` | `net_http` |
| RestClient | `rest-client` | `restclient` |

### Databases and caches

| Library | Gem | Instrumentation name |
| --- | --- | --- |
| Dalli (Memcached) | `dalli` | `dalli` |
| LMDB | `lmdb` | `lmdb` |
| Mongo (MongoDB) | `mongo` | `mongo` |
| Mysql2 (MySQL) | `mysql2` | `mysql2` |
| pg (PostgreSQL) | `pg` | `pg` |
| Redis | `redis` | `redis` |
| Trilogy (MySQL-compatible) | `trilogy` | `trilogy` |

### Background jobs and message queues

| Library | Gem | Instrumentation name |
| --- | --- | --- |
| Bunny (RabbitMQ) | `bunny` | `bunny` |
| Delayed::Job | `delayed_job` | `delayed_job` |
| Que (PostgreSQL queue) | `que` | `que` |
| Racecar (Kafka, consumer framework) | `racecar` | `racecar` |
| Rdkafka (Kafka, low-level client) | `rdkafka` | `rdkafka` |
| Resque | `resque` | `resque` |
| Ruby-Kafka | `ruby-kafka` | `ruby_kafka` |
| Sidekiq | `sidekiq` | `sidekiq` |

### RPC

| Library | Gem | Instrumentation name |
| --- | --- | --- |
| gRPC (client and server) | `grpc` | `grpc` |
| Gruf (gRPC framework) | `gruf` | `gruf` |

### GraphQL

| Library | Gem | Instrumentation name |
| --- | --- | --- |
| GraphQL-Ruby | `graphql` | `graphql` |

### Concurrency

| Library | Gem | Instrumentation name |
| --- | --- | --- |
| Concurrent Ruby | `concurrent-ruby` | `concurrent_ruby` |

### Task runners

| Library | Gem | Instrumentation name |
| --- | --- | --- |
| Rake | `rake` | `rake` |

### AI

| Library | Gem | Instrumentation name |
| --- | --- | --- |
| Anthropic | `anthropic` | `anthropic` |

### Cloud / AWS

| Library | Gem | Instrumentation name |
| --- | --- | --- |
| AWS SDK | `aws-sdk-*` | `aws_sdk` |

### Other

| Library | Gem | Instrumentation name |
| --- | --- | --- |
| Koala (Facebook Graph API) | `koala` | `koala` |
