
function transform(PizzaOrderRequest payload, string orderId) returns KitchenOrderRequest => {
    orderId: orderId,
    items: payload.items
};
