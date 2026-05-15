import ballerina/log;
import ballerinax/kafka;

// Kafka listener for kitchen events
listener kafka:Listener kitchenEventsListener = new (kafkaBootstrapServers, {
    groupId: kafkaGroupId,
    topics: kafkaTopic,
    offsetReset: "earliest"
});

service kafka:Service on kitchenEventsListener {

    remote function onConsumerRecord(kafka:AnydataConsumerRecord[] messages, kafka:Caller caller) returns error? {
        foreach kafka:AnydataConsumerRecord kafkaRecord in messages {
            do {
                byte[] rawValue = check kafkaRecord.value.ensureType();
                string rawJson = check string:fromBytes(rawValue);
                json eventJson = check rawJson.fromJsonString();

                json eventTypeJson = check eventJson.eventType;
                string eventType = eventTypeJson.toString();

                xml eventXml;
                if eventType == "ORDER_PLACED" {
                    eventXml = check transformOrderPlaced(eventJson);
                } else if eventType == "TICKET_FIRED" {
                    eventXml = check transformTicketFired(eventJson);
                } else if eventType == "PREP_COMPLETED" {
                    eventXml = check transformPrepCompleted(eventJson);
                } else if eventType == "ORDER_READY" {
                    eventXml = check transformOrderReady(eventJson);
                } else if eventType == "INVENTORY_ALERT" {
                    eventXml = check transformInventoryAlert(eventJson);
                } else {
                    log:printWarn("Unknown event type received, skipping", eventType = eventType);
                    continue;
                }

                check dispatchEvent(eventType, eventXml, eventJson);
            } on fail error processingError {
                log:printError("Failed to process Kafka record", 'error = processingError);
            }
        }
    }

    remote function onError(kafka:Error kafkaError) returns error? {
        log:printError("Kafka consumer error", 'error = kafkaError);
    }
}
