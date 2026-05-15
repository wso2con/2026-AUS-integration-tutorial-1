// Kitchen event types

type OrderItem record {
    string id;
    string name;
    string[] mods?;
};

type OrderPlacedEvent record {
    string eventId;
    string eventType;
    string orderId;
    OrderItem[] items;
    string timestamp;
};

type TicketFiredEvent record {
    string eventId;
    string eventType;
    string orderId;
    string station;
    string timestamp;
};

type PrepCompletedEvent record {
    string eventId;
    string eventType;
    string orderId;
    string station;
    string chefId;
    string timestamp;
};

type OrderReadyEvent record {
    string eventId;
    string eventType;
    string orderId;
    string pickupLocation;
    string timestamp;
};

type InventoryAlertEvent record {
    string eventId;
    string eventType;
    string ingredient;
    string status;
    int remainingQuantity;
    string timestamp;
};
