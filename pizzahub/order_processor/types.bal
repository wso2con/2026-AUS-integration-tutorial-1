
public type PizzaItem record {|
    string pizza;
    string size;
    int quantity;
|};

public type PizzaOrderRequest record {|
    string customerId;
    string customerName;
    string phone;
    string address;
    string email;
    PizzaItem[] items;
    string paymentMethod;
|};

public type PizzaOrderResponse record {|
    string orderId;
    string status;
    int estimatedReadyTime;
    string deliveryPartner;
    int deliveryEtaMinutes;
|};

type KitchenOrderRequest record {|
    string orderId;
    PizzaItem[] items;
|};

type KitchenOrderResponse record {|
    string orderId;
    string status;
    int etaMinutes;
|};

type DeliveryResponse record {|
    string orderId;
    string deliveryPartner;
    int etaMinutes;
|};