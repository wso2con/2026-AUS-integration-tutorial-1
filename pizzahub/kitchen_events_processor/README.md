# Kitchen Events Processor

A Ballerina-based event processing integration that consumes kitchen lifecycle events from Kafka, transforms them from JSON to XML (or plain text where appropriate), and routes them to the correct downstream systems — a Customer Notification service, a POS system, and an Analytics service.

This integration is part of the **PizzaHub** sample and demonstrates a content-based routing pattern over an event-driven backbone.

## Overview

A Kafka topic carries events emitted by the kitchen as an order moves through its lifecycle (placed → ticket fired → prep complete → ready). Inventory alerts are emitted on the same topic when ingredients run low. This service consumes those events and fans them out to the three downstream systems that need to know about them, applying per-system formatting along the way.

```
                                    +-------------------------------+
                                    |   Customer Notification API   |
                                    |   (plain text /notify)        |
                                    +-------------------------------+
                                          ^
                                          |  ORDER_PLACED, ORDER_READY
                                          |
+------------------+                +-----+----------------+        +------------------+
|  Kafka topic     | -------------> |  kitchen_events_     | -----> |   POS System     |
|  kitchen-events  |   JSON events  |  processor           |        |   (XML /events)  |
+------------------+                |  (Ballerina)         |        +------------------+
                                    +-----+----------------+              ^
                                          |                               | TICKET_FIRED, PREP_COMPLETED, ORDER_READY
                                          |
                                          v
                                    +-------------------------------+
                                    |   Analytics Service           |
                                    |   (XML /events)               |
                                    +-------------------------------+
                                       ^ all events
```

## Supported events

The consumer dispatches based on the `eventType` field in the incoming JSON. Five event types are handled; unknown types are logged and skipped.

| Event type        | Source record         | Description                                     |
| ----------------- | --------------------- | ----------------------------------------------- |
| `ORDER_PLACED`    | `OrderPlacedEvent`    | A new order has been confirmed                  |
| `TICKET_FIRED`    | `TicketFiredEvent`    | A kitchen ticket has been sent to a station    |
| `PREP_COMPLETED`  | `PrepCompletedEvent`  | A chef has finished prepping an item            |
| `ORDER_READY`     | `OrderReadyEvent`     | The full order is ready for pickup              |
| `INVENTORY_ALERT` | `InventoryAlertEvent` | An ingredient has dropped to or below threshold |

Type definitions live in `types.bal`.

## Routing rules

Each event type maps to a specific set of destinations and payload formats. The logic lives in `dispatchEvent` (`functions.bal`).

| Event type        | Customer Notification (text) | POS System (XML) | Analytics (XML) |
| ----------------- | :--------------------------: | :--------------: | :-------------: |
| `ORDER_PLACED`    | yes                          | no               | yes             |
| `TICKET_FIRED`    | no                           | yes              | yes             |
| `PREP_COMPLETED`  | no                           | yes              | yes             |
| `ORDER_READY`     | yes                          | yes              | yes             |
| `INVENTORY_ALERT` | no                           | no               | yes             |

Customer notifications are sent as `text/plain` with a human-readable message built by `buildCustomerNotificationText`. All other downstream calls send `application/xml`.

## Project structure

```
kitchen_events_processor/
├── Ballerina.toml         Package metadata (org, name, version, distribution)
├── Config.toml            Example runtime configuration (gitignored in production)
├── Dependencies.toml      Auto-generated dependency lockfile
├── main.bal               Kafka listener and service entry point
├── types.bal              Record type definitions for each event
├── config.bal             Configurable variable declarations
├── connections.bal        HTTP client declarations for downstream systems
├── functions.bal          Event transformations and dispatch logic
├── agents.bal             (placeholder, currently empty)
├── automation.bal         (placeholder, currently empty)
└── data_mappings.bal      (placeholder, currently empty)
```

## Prerequisites

- **Ballerina** `2201.13.4` (Swan Lake) or compatible. Install from [ballerina.io/downloads](https://ballerina.io/downloads/).
- **Apache Kafka** broker reachable from the runtime, with the configured topic created.
- **Downstream HTTP endpoints** for customer notifications, POS, and analytics. A mock service such as [Beeceptor](https://beeceptor.com/), [webhook.site](https://webhook.site/), or a local stub will work for development.

## Configuration

All runtime configuration is provided via `Config.toml` (or environment variables / command-line flags — see the [Ballerina configurable variables guide](https://ballerina.io/learn/provide-values-to-configurable-variables/)).

```toml
[mohan.kitchen_events_processor]
kafkaBootstrapServers = "localhost:9092"
kafkaTopic = "kitchen-events"
kafkaGroupId = "kitchen-event-consumer"
customerNotificationEndpoint = "https://example.com/customer"
posSystemEndpoint = "https://example.com/pos"
analyticsEndpoint = "https://example.com/analytics"
```

| Key                            | Purpose                                                              |
| ------------------------------ | -------------------------------------------------------------------- |
| `kafkaBootstrapServers`        | Comma-separated Kafka broker list                                    |
| `kafkaTopic`                   | Topic the consumer subscribes to                                     |
| `kafkaGroupId`                 | Consumer group ID (used for offset tracking)                         |
| `customerNotificationEndpoint` | Base URL of the customer notification service (posts to `/notify`)   |
| `posSystemEndpoint`            | Base URL of the POS system (posts to `/events`)                      |
| `analyticsEndpoint`            | Base URL of the analytics service (posts to `/events`)               |

The Kafka listener is configured with `offsetReset: "earliest"`, so a fresh consumer group will replay the topic from the beginning.

## Build and run

From the project root:

```bash
# Build the package
bal build

# Run directly from source
bal run

# Or run the built JAR
java -jar target/bin/kitchen_events_processor.jar
```

To override config values without editing `Config.toml`:

```bash
BAL_CONFIG_FILES=./Config.toml bal run
```

## Sample event payloads

Publish these to the configured Kafka topic to exercise each path. Values must be a JSON string serialized to UTF-8 bytes (the default for the Ballerina Kafka producer).

**`ORDER_PLACED`**

```json
{
  "eventId": "evt-001",
  "eventType": "ORDER_PLACED",
  "orderId": "ORD-10293",
  "items": [
    { "id": "PIZ-001", "name": "Margherita", "mods": ["extra-cheese"] },
    { "id": "PIZ-007", "name": "Pepperoni" }
  ],
  "timestamp": "2026-05-14T12:30:00Z"
}
```

**`TICKET_FIRED`**

```json
{
  "eventId": "evt-002",
  "eventType": "TICKET_FIRED",
  "orderId": "ORD-10293",
  "station": "OVEN-1",
  "timestamp": "2026-05-14T12:30:05Z"
}
```

**`PREP_COMPLETED`**

```json
{
  "eventId": "evt-003",
  "eventType": "PREP_COMPLETED",
  "orderId": "ORD-10293",
  "station": "OVEN-1",
  "chefId": "CHEF-42",
  "timestamp": "2026-05-14T12:42:00Z"
}
```

**`ORDER_READY`**

```json
{
  "eventId": "evt-004",
  "eventType": "ORDER_READY",
  "orderId": "ORD-10293",
  "pickupLocation": "Counter-2",
  "timestamp": "2026-05-14T12:45:00Z"
}
```

**`INVENTORY_ALERT`**

```json
{
  "eventId": "evt-005",
  "eventType": "INVENTORY_ALERT",
  "ingredient": "MOZZ-001",
  "status": "LOW",
  "remainingQuantity": 2,
  "timestamp": "2026-05-14T12:46:00Z"
}
```

## Sample downstream payloads

An `ORDER_PLACED` event produces:

- **POST `/notify`** on the customer notification endpoint with `Content-Type: text/plain`:

  ```
  Your order ORD-10293 has been placed successfully. We'll start preparing it right away!
  ```

- **POST `/events`** on the analytics endpoint with `Content-Type: application/xml`:

  ```xml
  <orderPlacedEvent>
    <eventId>evt-001</eventId>
    <eventType>ORDER_PLACED</eventType>
    <orderId>ORD-10293</orderId>
    <items>
      <item>
        <id>PIZ-001</id>
        <name>Margherita</name>
        <modifications>
          <modification>extra-cheese</modification>
        </modifications>
      </item>
      <item>
        <id>PIZ-007</id>
        <name>Pepperoni</name>
        <modifications></modifications>
      </item>
    </items>
    <timestamp>2026-05-14T12:30:00Z</timestamp>
  </orderPlacedEvent>
  ```

An `ORDER_READY` event fans out to **all three** endpoints — text to customer notification, XML to both POS and analytics.

## Error handling

- Per-message errors are caught inside the Kafka record loop in `main.bal`; a failure on one message logs an error and continues with the next, so a single bad event does not stop the consumer.
- Kafka consumer errors are surfaced through the `onError` remote function and logged.
- Unknown `eventType` values are logged as warnings and skipped.

Note: the current implementation does **not** retry failed HTTP dispatches or commit Kafka offsets explicitly. For production use, consider adding a dead-letter topic, retry with backoff (e.g., the `ballerina/lang.runtime` sleep + bounded retry loop), and explicit offset commit after successful dispatch.

## Local development with a mock backend

For quick end-to-end testing without standing up the three downstream services:

1. Create a free mock endpoint (e.g., `https://your-name.free.beeceptor.com`).
2. Point all three endpoint configs at the same mock URL.
3. Use the Beeceptor dashboard to inspect the requests as you publish test events to Kafka.

A local Kafka can be started with the standard Confluent or Bitnami Docker Compose setup, then events produced with `kafka-console-producer.sh` or a small Ballerina producer script.


