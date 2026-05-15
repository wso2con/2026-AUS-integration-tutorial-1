import ballerina/http;
import ballerina/log;

// Transform ORDER_PLACED event to XML
function transformOrderPlaced(json eventJson) returns xml|error {
    OrderPlacedEvent orderEvent = check eventJson.cloneWithType();
    xml itemsXml = xml ``;
    foreach OrderItem orderItem in orderEvent.items {
        xml modsXml = xml ``;
        string[]? mods = orderItem.mods;
        if mods is string[] {
            foreach string modValue in mods {
                modsXml = modsXml + xml `<modification>${xml:createText(modValue)}</modification>`;
            }
        }
        xml singleItemXml = xml `<item><id>${xml:createText(orderItem.id)}</id><name>${xml:createText(orderItem.name)}</name><modifications>${modsXml}</modifications></item>`;
        itemsXml = itemsXml + singleItemXml;
    }
    xml eventXml = xml `<orderPlacedEvent><eventId>${xml:createText(orderEvent.eventId)}</eventId><eventType>${xml:createText(orderEvent.eventType)}</eventType><orderId>${xml:createText(orderEvent.orderId)}</orderId><items>${itemsXml}</items><timestamp>${xml:createText(orderEvent.timestamp)}</timestamp></orderPlacedEvent>`;
    return eventXml;
}

// Transform TICKET_FIRED event to XML
function transformTicketFired(json eventJson) returns xml|error {
    TicketFiredEvent ticketEvent = check eventJson.cloneWithType();
    xml eventXml = xml `<ticketFiredEvent><eventId>${xml:createText(ticketEvent.eventId)}</eventId><eventType>${xml:createText(ticketEvent.eventType)}</eventType><orderId>${xml:createText(ticketEvent.orderId)}</orderId><station>${xml:createText(ticketEvent.station)}</station><timestamp>${xml:createText(ticketEvent.timestamp)}</timestamp></ticketFiredEvent>`;
    return eventXml;
}

// Transform PREP_COMPLETED event to XML
function transformPrepCompleted(json eventJson) returns xml|error {
    PrepCompletedEvent prepEvent = check eventJson.cloneWithType();
    xml eventXml = xml `<prepCompletedEvent><eventId>${xml:createText(prepEvent.eventId)}</eventId><eventType>${xml:createText(prepEvent.eventType)}</eventType><orderId>${xml:createText(prepEvent.orderId)}</orderId><station>${xml:createText(prepEvent.station)}</station><chefId>${xml:createText(prepEvent.chefId)}</chefId><timestamp>${xml:createText(prepEvent.timestamp)}</timestamp></prepCompletedEvent>`;
    return eventXml;
}

// Transform ORDER_READY event to XML
function transformOrderReady(json eventJson) returns xml|error {
    OrderReadyEvent readyEvent = check eventJson.cloneWithType();
    xml eventXml = xml `<orderReadyEvent><eventId>${xml:createText(readyEvent.eventId)}</eventId><eventType>${xml:createText(readyEvent.eventType)}</eventType><orderId>${xml:createText(readyEvent.orderId)}</orderId><pickupLocation>${xml:createText(readyEvent.pickupLocation)}</pickupLocation><timestamp>${xml:createText(readyEvent.timestamp)}</timestamp></orderReadyEvent>`;
    return eventXml;
}

// Transform INVENTORY_ALERT event to XML
function transformInventoryAlert(json eventJson) returns xml|error {
    InventoryAlertEvent inventoryEvent = check eventJson.cloneWithType();
    string remainingQty = inventoryEvent.remainingQuantity.toString();
    xml eventXml = xml `<inventoryAlertEvent><eventId>${xml:createText(inventoryEvent.eventId)}</eventId><eventType>${xml:createText(inventoryEvent.eventType)}</eventType><ingredient>${xml:createText(inventoryEvent.ingredient)}</ingredient><status>${xml:createText(inventoryEvent.status)}</status><remainingQuantity>${xml:createText(remainingQty)}</remainingQuantity><timestamp>${xml:createText(inventoryEvent.timestamp)}</timestamp></inventoryAlertEvent>`;
    return eventXml;
}

// Build a human-readable text message for customer notifications
function buildCustomerNotificationText(string eventType, json eventJson) returns string|error {
    if eventType == "ORDER_PLACED" {
        OrderPlacedEvent orderEvent = check eventJson.cloneWithType();
        return string `Your order ${orderEvent.orderId} has been placed successfully. We'll start preparing it right away!`;
    } else if eventType == "ORDER_READY" {
        OrderReadyEvent readyEvent = check eventJson.cloneWithType();
        return string `Great news! Your order ${readyEvent.orderId} is ready for pickup at ${readyEvent.pickupLocation}.`;
    }
    return error(string `No customer notification text defined for event type: ${eventType}`);
}

// Route and dispatch the event XML to the appropriate HTTP endpoint
function dispatchEvent(string eventType, xml eventXml, json eventJson) returns error? {
    string xmlPayload = eventXml.toString();
    map<string|string[]> xmlHeaders = {"Content-Type": "application/xml"};
    map<string|string[]> textHeaders = {"Content-Type": "text/plain"};

    // Customer Notification: send plain text message for order status changes
    if eventType == "ORDER_PLACED" || eventType == "ORDER_READY" {
        string textMessage = check buildCustomerNotificationText(eventType, eventJson);
        http:Response customerResponse = check customerNotificationClient->post("/notify", textMessage, headers = textHeaders);
        log:printInfo("Sent to customer notification endpoint", eventType = eventType, statusCode = customerResponse.statusCode);
    }

    // POS System: send XML for kitchen ticket and prep workflow events
    if eventType == "TICKET_FIRED" || eventType == "PREP_COMPLETED" || eventType == "ORDER_READY" {
        http:Response posResponse = check posSystemClient->post("/events", xmlPayload, headers = xmlHeaders);
        log:printInfo("Sent to POS system endpoint", eventType = eventType, statusCode = posResponse.statusCode);
    }

    // Analytics: forward all events for tracking and reporting
    http:Response analyticsResponse = check analyticsClient->post("/events", xmlPayload, headers = xmlHeaders);
    log:printInfo("Sent to analytics endpoint", eventType = eventType, statusCode = analyticsResponse.statusCode);
}
